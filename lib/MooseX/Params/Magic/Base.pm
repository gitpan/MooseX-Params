package MooseX::Params::Magic::Base;
BEGIN {
  $MooseX::Params::Magic::Base::VERSION = '0.002';
}

# ABSTRACT: Base class for building Variable::Magic wizards

use strict;
use warnings;

use Variable::Magic ();
use Package::Stash  ();

sub new
{
    my $stash = Package::Stash->new(shift);

    my @fields = qw(
        data
        get
        set
        len
        clear
        free
        copy
        local
        fetch
        store
        exists
        delete
        copy_key
        op_info
    );

    my %map;

    foreach my $field (@fields)
    {
        my $coderef = $stash->get_symbol("&$field");
        $map{$field} = $coderef if $coderef;
    }

    return Variable::Magic::wizard(%map);
}

1;

__END__
=pod

=for :stopwords Peter Shangov TODO invocant isa metaroles metarole multimethods sourcecode

=head1 NAME

MooseX::Params::Magic::Base - Base class for building Variable::Magic wizards

=head1 VERSION

version 0.002

=head1 AUTHOR

Peter Shangov <pshangov@yahoo.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Peter Shangov.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

