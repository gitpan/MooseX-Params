
use strict;
use warnings;

BEGIN { require 5.10.0; }

use ExtUtils::MakeMaker 6.31;



my %WriteMakefileArgs = (
  'ABSTRACT' => 'Parameters with meta, laziness and %_',
  'AUTHOR' => 'Peter Shangov <pshangov@yahoo.com>',
  'BUILD_REQUIRES' => {
    'Devel::Dwarn' => '0',
    'File::Find' => '0',
    'File::Temp' => '0',
    'Test::More' => '0',
    'Test::Most' => '0'
  },
  'CONFIGURE_REQUIRES' => {
    'ExtUtils::MakeMaker' => '6.31'
  },
  'DISTNAME' => 'MooseX-Params',
  'EXE_FILES' => [],
  'LICENSE' => 'perl',
  'NAME' => 'MooseX::Params',
  'PREREQ_PM' => {
    'Attribute::Handlers' => '0',
    'B::Hooks::EndOfScope' => '0',
    'Carp' => '0',
    'Class::MOP::Class' => '0',
    'List::Util' => '0',
    'Moose' => '0',
    'Moose::Exporter' => '0',
    'Moose::Meta::Class' => '0',
    'Moose::Meta::Method' => '0',
    'Moose::Role' => '0',
    'Moose::Util::MetaRole' => '0',
    'Moose::Util::TypeConstraints' => '0',
    'Package::Stash' => '0.18',
    'Perl6::Caller' => '0',
    'Scalar::Util' => '0',
    'Text::CSV_XS' => '0',
    'Try::Tiny' => '0',
    'Variable::Magic' => '0',
    'parent' => '0'
  },
  'VERSION' => '0.004',
  'test' => {
    'TESTS' => 't/*.t t/attributes/*.t'
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



