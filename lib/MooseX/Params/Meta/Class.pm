package MooseX::Params::Meta::Class;
BEGIN {
  $MooseX::Params::Meta::Class::VERSION = '0.003';
}

# ABSTRACT: The class metarole

use Moose::Role;

has 'parameters' =>
(
    is      => 'rw',
    isa     => 'ArrayRef',
    traits  => ['Array'],
    handles => { 'add_parameter' => 'push' },
);

no Moose::Role;

1;

__END__
=pod

=for :stopwords Peter Shangov TODO invocant isa metaroles metarole multimethods sourcecode

=head1 NAME

MooseX::Params::Meta::Class - The class metarole

=head1 VERSION

version 0.003

=head1 AUTHOR

Peter Shangov <pshangov@yahoo.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Peter Shangov.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

