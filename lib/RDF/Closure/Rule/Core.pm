package RDF::Closure::Rule::Core;

use 5.008;
use common::sense;

use Error qw[:try];
use RDF::Trine;

our $VERSION = '0.000_02';

sub name
{
	my ($self) = @_;
	return $self->{name};
}

sub debug
{
	my ($self, $message) = @_;
	printf("+ %s%s\n", $self->name, (defined $message ? ": $message" : ''))
		if $RDF::Closure::Engine::Core::debugGlobal;
}

sub apply_to_closure
{
	my ($self, $closure) = @_;
	throw Error "This method should not be called directly; subclasses should override it.";
}

1;
