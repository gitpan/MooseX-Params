package MooseX::Params::Util::Parameter;
BEGIN {
  $MooseX::Params::Util::Parameter::VERSION = '0.004';
}

# ABSTRACT: Parameter processing utilities

use strict;
use warnings;
use 5.10.0;
use Moose::Util::TypeConstraints qw(find_type_constraint);
use Try::Tiny qw(try catch);
use List::Util qw(max);
use Scalar::Util qw(isweak);
use Class::MOP::Class;
use Package::Stash;
use Perl6::Caller;
use B::Hooks::EndOfScope qw(on_scope_end); # magic fails without this, have to find out why ...
use Text::CSV_XS;
use MooseX::Params::Meta::Parameter;
use MooseX::Params::Magic::Wizard;

sub check_required
{
    my $param = shift;

    my $has_default = defined ($param->default) or $param->builder;
    my $is_required = $param->required;

    if ($is_required and !$has_default)
    {
        Carp::croak "Parameter " . $param->name . " is required";
    }
}

sub build
{
    my ($param, $stash) = @_;

    my $value;

    my $default = $param->default;

    if (defined $default and ref($default) ne 'CODE')
    {
        $value = $default;
    }
    else
    {
        my $coderef;

        if ($default)
        {
            $coderef = $default;
        }
        else
        {
            my $coderef = $stash->get_symbol('&' . $param->builder);
            Carp::croak("Cannot find builder " . $param->builder) unless $coderef;
        }

        $value = try {
            $coderef->();
        } catch {
            Carp::croak("Error executing builder for parameter " . $param->name . ": $_");
        };
    }

    return $value;
}

sub wrap
{
    my ($coderef, $package_name, $parameters, $key, $prototype) = @_;

    my $wizard = MooseX::Params::Magic::Wizard->new;

    my $wrapped = sub
    {
        # localize $self
        my $self = $_[0];
        no strict 'refs';
        local *{$package_name.'::self'} = $key ? $self : \$self;
        use strict 'refs';

        # localize and enchant %_
        local %_ = $key ? @_[1 .. $#_] : process(@_);
        Variable::Magic::cast(%_, $wizard,
            parameters => $parameters,
            self       => \$self,       # needed to pass as first argument to parameter builders
            wrapper    => \&wrap,
            package    => $package_name,
        );

        # execute for a parameter builder
        if ($key)
        {
            my $value = $coderef->($self, %_);
            $value = MooseX::Params::Util::Parameter::validate($parameters->{$key}, $value);
            return %_, $key => $value;
        }
        # execute for a method
        else
        {
            return $coderef->(@_);
        }
    };

    set_prototype($wrapped, $prototype) if $prototype;

    return $wrapped;
}

sub process
{
    my @parameters = @_;
    my $last_index = $#parameters;

    my $frame = 1;
    my ($package_name, $method_name) = caller($frame)->subroutine  =~ /^(.+)::(\w+)$/;
    my $stash = Package::Stash->new($package_name);

    my $meta = Class::MOP::Class->initialize($package_name);
    my $method = $meta->get_method($method_name);

    my @parameter_objects = $method->all_parameters if $method->has_parameters;

    return unless @parameter_objects;

    my $offset = $method->index_offset;

    my $last_positional_index = max
        map  { $_->index + $offset }
        grep { $_->type eq 'positional' }
        @parameter_objects;

    $last_positional_index++;

    my %named = @parameters[ $last_positional_index .. $last_index ];

    my %return_values;

    foreach my $param (@parameter_objects)
    {
        my ( $is_set, $original_value );

        if ( $param->type eq 'positional' )
        {
            my $index = $param->index + $offset;
            $is_set = $index > $last_index ? 0 : 1;
            $original_value = $parameters[$index] if $is_set;
        }
        else
        {
            $is_set = exists $named{$param->name};
            $original_value = $named{$param->name} if $is_set;
        }

        my $is_required = $param->required;
        my $is_lazy = $param->lazy;
        my $has_default = ( defined $param->default or $param->builder );

        my $value;

        # if required but not set, attempt to build the value
        if ( !$is_set and !$is_lazy and $is_required )
        {
            MooseX::Params::Util::Parameter::check_required($param);
            $value = MooseX::Params::Util::Parameter::build($param, $stash);
        }
        # if not required and not set, but not lazy either, check for a default
        elsif ( !$is_set and !$is_required and !$is_lazy and $has_default )
        {
            $value = MooseX::Params::Util::Parameter::build($param, $stash);
        }
        # lazy parameters are built later
        elsif ( !$is_set and $is_lazy)
        {
            next;
        }
        elsif ( $is_set )
        {
            $value = $original_value;
        }

        $value = MooseX::Params::Util::Parameter::validate($param, $value);

        $return_values{$param->name} = $value;

        if ($param->weak_ref and !isweak($value))
        {
            #weaken($value);
            #weaken($return_values{$param->name});
        }
    }

    return %return_values;
}


sub validate
{
    my ($param, $value) = @_;

    if ( $param->constraint )
    {
        my $constraint = find_type_constraint($param->constraint)
            or Carp::croak("Could not find definition of type '" . $param->constraint . "'");

        # coerce
        if ($param->coerce and $constraint->has_coercion)
        {
            $value = $constraint->assert_coerce($value);
        }

        $constraint->assert_valid($value);
    }

    return $value;
}

sub parse_params_attribute
{
    my $string = shift;
    my @params;

    $string =~ s/\R//g;

    my $csv_parser = Text::CSV_XS->new({ allow_loose_quotes => 1 });
    $csv_parser->parse($string) or Carp::croak("Cannot parse param specs");

    my $format = qr/^
        # TYPE AND COERCION
        ( (?<coerce>\&)? (?<type> [\w\:\[\]]+) \s+ )?

        # SLURPY
        (?<slurpy>\*)?

        # NAME
        (
             ( (?<named>:) (?<init_arg>\w*) \( (?<name>\w+) \) )
            |( (?<named>:)?                    (?<init_arg>(?<name>\w+)) )
        )

        # REQUIRED OR OPTIONAL
        (?<required>[!?])? \s*

        # DEFAULT VALUE
        (
            (?<default>=)\s*(
                  (?<number> \d+ )
                | ( (?<code>\w+) (\(\))? )
                | ( (?<delimiter>["']) (?<string>.*) \g{delimiter} )
             )?
        )?

    $/x;


    foreach my $param ($csv_parser->fields)
    {
        $param =~ s/^\s*//;
        $param =~ s/\s*$//;

        if ($param =~ $format)
        {
            my %options =
            (
                name     => $+{name},
                init_arg => $+{init_arg} eq '' ? undef : $+{init_arg},
                required => ( defined $+{required} and $+{required} eq '?' ) ? 0 : 1,
                type     => $+{named} ? 'named' : 'positional',
                slurpy   => $+{slurpy} ? 1 : 0,
                isa      => defined $+{type} ? $+{type} : undef,
                coerce   => $+{coerce} ? 1 : 0,
                default  => defined $+{number} ? $+{number} : $+{string},
                builder  => ( defined $+{default} and not defined $+{number} and not defined $+{string} )
                                ? ( defined $+{code} ? $+{code} : "_build_param_$+{name}" ) : undef,
                lazy     => ( defined $+{default} and not defined $+{number} and not defined $+{string} ) ? 1 : 0,
            );

            push @params, \%options;
        }
        else
        {
            Carp::croak "Error parsing parameter specification '$param'";
        }
    }

    return @params;
}

sub inflate_parameters
{
    my $package = shift;
    my @params = @_;
    my $position = 0;
    my @inflated_parameters;

    for ( my $i = 0; $i <= $#params; $i++ )
    {
        my $current = $params[$i];
        my $next = $i < $#params ? $params[$i+1] : undef;
        my $parameter;

        if (ref $next)
        # next value is a parameter specifiction
        {
            $parameter = MooseX::Params::Meta::Parameter->new(
                type    => 'positional',
                index   => $position,
                name    => $current,
                package => $package,
                %$next,
            );
            $i++;
        }
        else
        {
            $parameter = MooseX::Params::Meta::Parameter->new(
                type    => 'positional',
                index   => $position,
                name    => $current,
                package => $package,
            );
        }

        push @inflated_parameters, $parameter;
        $position++;
    }

    my %inflated_parameters = map { $_->name => $_ } @inflated_parameters;

    return %inflated_parameters;
}

1;

__END__
=pod

=for :stopwords Peter Shangov TODO invocant isa metaroles metarole multimethods sourcecode

=head1 NAME

MooseX::Params::Util::Parameter - Parameter processing utilities

=head1 VERSION

version 0.004

=head1 AUTHOR

Peter Shangov <pshangov@yahoo.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Peter Shangov.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
