package RDF::Closure::Rule::PatternMatcher;

use 5.008;
use common::sense;

use Error qw[:try];
use RDF::Trine;
use Scalar::Util qw[blessed];

use base qw[RDF::Closure::Rule::Core];

our $VERSION = '0.000_03';

sub new
{
	my ($class, $pattern, $template, $name) = @_;
	
	throw Error::Simple("Pattern must be a RDF::Trine::Pattern.")
		unless blessed($pattern) && $pattern->isa('RDF::Trine::Pattern');
	throw Error::Simple("Template must be a RDF::Trine::Pattern.")
		unless blessed($template) && $template->isa('RDF::Trine::Pattern');
	
	bless { pattern => $pattern, template => $template, name => $name }, $class;
}

sub pattern
{
	$_[0]->{pattern};
}

sub template
{
	$_[0]->{template};
}

sub apply_to_closure
{
	my ($self, $closure) = @_;
	$self->debug;
	
	$closure->graph->get_pattern($self->pattern)->each(sub {
		my $bound = $self->template->bind_variables($_[0]);
		$closure->store_triple($_) foreach $bound->triples;
	});
	
	$self;
}

1;
