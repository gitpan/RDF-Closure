use strict;
use warnings;

use inc::Module::Install;

my $dist = 'RDF-Closure';
my $fn   = "lib/$dist.pm"; $fn =~ s#-#/#g;

name                $dist;
perl_version_from   $fn;
version_from        $fn;
abstract_from       $fn;
readme_from         $fn;
author              'Toby Inkster <tobyink@cpan.org>';
license             'perl';

requires            'Carp'               => 0;
requires            'common::sense'      => 0;
requires            'Data::UUID'         => 0;
requires            'DateTime'           => 0;
requires            'DateTime::Format::Strptime'  => 0;
requires            'DateTime::Format::XSD'  => 0;
requires            'DateTime::TimeZone' => 0;
requires            'Error'              => 0;
requires            'Exporter'           => 0;
requires            'Math::BigInt'       => 0;
requires            'MIME::Base64'       => 0;
requires            'Module::Pluggable'  => 0;
requires            'namespace::clean'   => 0;
requires            'Parse::RecDescent'  => 0;
requires            'RDF::Trine'         => '0.133';
requires            'Scalar::Util'       => 0;
test_requires       'Test::More'         => '0.61';
requires            'URI'                => 0;
requires            'XML::LibXML'        => 0;

# install_script 'fingerw';

resources(
	'homepage'   => "http://search.cpan.org/dist/$dist/",
	'repository' => "http://goddamn.co.uk/viewvc/perlmods/$dist/",
	'bugtracker' => "http://rt.cpan.org/Dist/Display.html?Queue=$dist",
	);

keywords(qw(RDF Reasoning Inference OWL RDFS Rules RL));
	
write_doap_changes;
write_doap_changes_xml;

auto_install;
WriteAll(
	'meta' => 1,
	'sign' => 1,
	);
