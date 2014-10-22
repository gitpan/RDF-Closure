package RDF::Closure::Engine::Core;

use 5.008;
use common::sense;

use Data::UUID;
use Error qw[:try];
use RDF::Trine;
use RDF::Trine::Namespace qw[RDF RDFS OWL XSD];
use Scalar::Util qw[blessed];

use constant {
	TRUE    => 1,
	FALSE   => 0,
	};

our $VERSION = '0.000_02';

our $debugGlobal = FALSE;

use namespace::clean;

use base qw[RDF::Closure::Engine];

our (@Rules, @OneTimeRules);

# TOBYINK: addition
sub new
{
	my ($class, @args) = @_;
	my $self = bless {}, $class;
	return $self->__init__(@args);
}

sub __init__
{
	my ($self, $graph, $axioms, $daxioms, $rdfs) = @_;
	$rdfs    = FALSE unless defined $rdfs;
	$graph ||= RDF::Trine::Model->temporary_model;
	
	$self->{_debug} = $debugGlobal;

	# Calculate the maximum 'n' value for the '_i' type predicates (see Horst's paper)	
	# TOBYINK - this seems like a poor technique. better to just grep all statements to
	#           find the highest one?
	{
		my $n      = 0;
		my $maxnum = 0;
		my $cont   = TRUE;
		while ($cont)
		{
			$cont = FALSE;
			my $predicate = $RDF->uri(sprintf('_%d', $n));
			if ($graph->count_statements(undef, $predicate, undef))
			{
				$maxnum = $n++;
				$cont   = TRUE;
			}
		}
		$self->{IMaxNum} = $maxnum;
	}
	
	$self->{graph}   = $graph;
	$self->{axioms}  = $axioms;
	$self->{daxioms} = $daxioms;
	$self->{rdfs}    = $rdfs;
	$self->{error_messages} = [];
	$self->{options} = {};
	$self->empty_stored_triples;
	
	# TOBYINK: addition
	{
		my $uuid      = Data::UUID->new;
		my $throwaway = sub {
			RDF::Trine::Node::Resource->new(sprintf('urn:uuid:%s', $uuid->create_str));
			};
		$self->{inferred_context} = $throwaway->();
		$self->{imported_context} = $throwaway->();
		$self->{axiom_context}    = $throwaway->();
		$self->{daxiom_context}   = $throwaway->();
		$self->{uri_generator}    = $throwaway;
	}
	
	return $self;
}

# TOBYINK: addition
sub graph
{
	my ($self) = @_;
	return $self->{graph};
}

sub add_error
{
	my ($self, $message, @params) = @_;
	
	@params = map {
		(blessed($_) and $_->isa('RDF::Trine::Node')) ? $_->as_ntriples : $_;
		} @params;
	$message = sprintf($message, @params)
		if @params;
	
	printf("** %s\n", $message)
		if $self->{_debug};
	
	push @{ $self->{error_messages} }, $message
		unless grep { $message eq $_ } @{ $self->{error_messages} };
		
	return $self;
}

sub error_messages
{
	my ($self) = @_;
	return @{ $self->{error_messages} };
}

sub pre_process
{
	my ($self) = @_;
	return $self;
}

sub post_process
{
	my ($self) = @_;
	return $self;
}

sub rules
{
	my ($self, $t, $cycle_num) = @_;
	return;
}

sub add_axioms
{
	my ($self) = @_;
	return $self;
}

sub add_daxioms
{
	my ($self) = @_;
	return $self;
}

sub one_time_rules
{
	my ($self) = @_;
	return;
}

sub get_literal_value
{
	my ($self, $node) = @_;
	
	return $node->literal_value if $node->is_literal;
	return '????';
}

sub empty_stored_triples
{
	my ($self) = @_;
	$self->{added_triples} = [];
	return $self;
}

sub flush_stored_triples
{
	my ($self) = @_;

	eval { $self->graph->_store->clear_restrictions; };

	$self->graph->begin_bulk_ops;
	$self->graph->add_statement($_, $self->{inferred_context})
		foreach @{ $self->{added_triples} };
	$self->graph->end_bulk_ops;
	
	$self->empty_stored_triples;
}

sub store_triple
{
	my $self = shift;
	if ($_[0]->isa('RDF::Trine::Statement'))
	{
		foreach (@_)
		{
			next if $self->graph->count_statements($_->subject, $_->predicate, $_->object);
			printf("%s\n", $_->sse) if $self->{_debug};
			push @{ $self->{added_triples} }, $_;
		}
	}
	else
	{
		my $st = RDF::Trine::Statement->new(@_);
		return $self->store_triple($st);
	}
	return $self;
}

{
	my (@ST, @OTHER);
	
	sub closure
	{
		my ($self, $is_subsequent) = @_;
		
		unless ($is_subsequent)
		{
			$self->pre_process;
			$self->add_axioms    if $self->{axioms};
			$self->add_daxioms   if $self->{daxioms};
			$self->flush_stored_triples;
			
			$_->apply_to_closure($self)
				foreach $self->one_time_rules;
			
			$self->flush_stored_triples;
		}

		my $new_cycle = TRUE;
		my $cycle_num = 0;

		# figure out which rules can be applied to individual statements
		unless ($self->{options}->{technique} eq 'RULE'
			or @ST
			or @OTHER)
		{
			foreach my $r ($self->rules)
			{
				if ($r->can('apply_to_closure_given_statement'))
				{
					push @ST, $r;
				}
				else
				{
					push @OTHER, $r;
				}
			}
		}
		
		while ($new_cycle)
		{	
			$cycle_num++;
			printf("----- Cycle #%d\n", $cycle_num) if $self->{_debug};
			
			# Alternative techniques for applying rules.
			if ($self->{options}->{technique} eq 'RULE')
			{
				$_->apply_to_closure($self)
					foreach $self->rules;
			}
			else
			{
				$self->graph->as_stream->each(sub {
					$_->apply_to_closure_given_statement($self, $_[0])
						foreach @ST;
				});
				$_->apply_to_closure($self)
					foreach @OTHER;
			}
			
			$new_cycle = scalar @{ $self->{added_triples} };
			$self->flush_stored_triples;
		}

		$self->post_process;
		$self->flush_stored_triples;
		
		return $self;
	}
}

sub reset
{
	my ($self) = @_;
	$self->graph->begin_bulk_ops;
	$self->graph->remove_statements(undef, undef, undef, $self->{$_})
		foreach qw[inferred_context imported_context axiom_context daxiom_context];
	$self->graph->end_bulk_ops;
	return $self;
}

sub one_time_rules
{
	my ($proto) = @_;
	$proto = ref $proto if ref $proto;
	my @rv;
	eval sprintf('@rv = @%s::%s', $proto, 'OneTimeRules');
	return @rv;
}

sub rules
{
	my ($proto) = @_;
	$proto = ref $proto if ref $proto;
	my @rv;
	eval sprintf('@rv = @%s::%s', $proto, 'Rules');
	return @rv;
}

1;

=head1 NAME

RDF::Closure::Engine::Core - common code used by inference engines

=head1 ANALOGOUS PYTHON

RDFClosure/Closure.py

=head1 DESCRIPTION

This is a basic forward-chaining engine.

Inference engines don't have to inherit from this, but it helps.

=head1 SEE ALSO

L<RDF::Closure::Engine>.

L<http://www.perlrdf.org/>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT

Copyright 2008-2011 Ivan Herman

Copyright 2011 Toby Inkster

This library is free software; you can redistribute it and/or modify it
under any of the following licences:

=over

=item * The Artistic License 1.0 L<http://www.perlfoundation.org/artistic_license_1_0>.

=item * The GNU General Public License Version 1 L<http://www.gnu.org/licenses/old-licenses/gpl-1.0.txt>,
or (at your option) any later version.

=item * The W3C Software Notice and License L<http://www.w3.org/Consortium/Legal/2002/copyright-software-20021231>.

=item * The Clarified Artistic License L<http://www.ncftp.com/ncftp/doc/LICENSE.txt>.

=back

=cut

