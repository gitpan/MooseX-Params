package MooseX::Params::Magic::Wizard;
BEGIN {
  $MooseX::Params::Magic::Wizard::VERSION = '0.005';
}

# ABSTRACT: Magic behavior for %_

use 5.010;
use strict;
use warnings;
use Carp ();
use MooseX::Params::Util;
use MooseX::Params::Magic::Data;
use parent 'MooseX::Params::Magic::Base';

sub data
{
    my ($ref, %data) = @_;
    return MooseX::Params::Magic::Data->new(%data);
}

sub fetch
{
    my ( $ref, $data, $key ) = @_;

    # throw exception if $key is not a valid parameter name
    my @allowed = $data->allowed_parameters;
    Carp::croak("Attempt to access non-existany parameter $key")
        unless $key ~~ @allowed;

    # quit if this parameter has already been processed
    return if exists $ref->{$key};

    my $builder = $data->get_parameter($key)->builder_sub;
    my $wrapped = $data->wrap($builder, $data->package, $data->parameters, $key);

    # this check should not be necessary
    if ($builder)
    {
        my %updated = $wrapped->(%$ref);
        foreach my $updated_key ( keys %updated )
        {
            $ref->{$updated_key} = $updated{$updated_key}
                unless exists $ref->{$updated_key};
        }
    }
    else
    {
        $ref->{$key} = undef;
    }
}

sub store
{
    Carp::croak "Attempt to modify read-only parameter" if caller ne __PACKAGE__;
}

1;

__END__
=pod

=for :stopwords Peter Shangov TODO invocant isa metaroles metarole multimethods sourcecode
backwards buildargs checkargs slurpy preprocess

=head1 NAME

MooseX::Params::Magic::Wizard - Magic behavior for %_

=head1 VERSION

version 0.005

=head1 AUTHOR

Peter Shangov <pshangov@yahoo.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Peter Shangov.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

