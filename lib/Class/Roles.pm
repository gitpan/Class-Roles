package Class::Roles;

use strict;
use Scalar::Util 'blessed';

use vars '$VERSION';
$VERSION = '0.20';

my %actions =
(
	role  => \&role,
	does  => \&does,
	multi => \&multi,
);

my (%roles, %does);

sub import
{
	my $caller          = caller();
	my ($self, %args)   = @_;

	while (my ($name, $value) = each %args)
	{
		$actions{ $name }->( $caller, $value ) if exists $actions{ $name };
	}
}

sub role
{
	my ($caller, $role)   = @_;
	$role                 = [ $role ] unless ref $role eq 'ARRAY';
	$roles{ $caller }   ||= [];

	install_methods( $caller, $caller, @$role );
}

sub multi
{
	my ($caller, $multi) = @_;

	while (my ($role, $methods) = each %$multi)
	{
		$methods = [ $methods ] unless ref $methods eq 'ARRAY';
		install_methods( $caller, $role, @$methods );
	}
}

sub does
{
	my ($caller, $role) = @_;

	no strict 'refs';
	for my $method (@{ $roles{ $role } })
	{
		my ($name, $code)           = @$method;
		my $export_name             = $caller . '::' . $name;
		*{ $export_name }           = $code unless defined &{ $export_name };
	}

	$does{ $caller }{ $role } = 1;
}

sub install_methods
{
	my ($source, $role, @methods) = @_;

	no strict 'refs';

	for my $method (@methods)
	{
		push @{ $roles{ $role } },
			[ $method, \&{ $source . '::' . $method } ];
	}
}

sub universal_does
{
	my ($invocant, $role) = @_;
	my $class               = blessed $invocant || $invocant;

	return 1 if $class eq $role;
	return 1 if exists $does{ $class }{ $role };

	return check_isa( $class, $role );
}

sub check_isa
{
	my ($class, $role) = @_;

	no strict 'refs';

	my @isa = @{ $class . '::ISA' };
	for my $parent (@isa)
	{
		return 1 if $parent->does( $role ) or check_isa( $parent, $role );
	}

	return;
}

*UNIVERSAL::does = \&universal_does;

1;
__END__

=head1 NAME

Class::Roles - use Perl 6 roles in Perl 5

=head1 SYNOPSIS

	# provide a role
	package Animal;

	use Class::Roles role => [qw( eat sleep )]

	sub eat   { 'chomp chomp' }; 
	sub sleep { 'snore snore' };

	# use a role
	package Dog;

	use Class::Roles does => 'Animal';

	# test that a class or object performs a role
	$dog->does( 'Animal' );
	Dog->does( 'Animal' );
	UNIVERSAL::does( 'Dog', 'Animal' );

	# test that subclasses also respect their parents' roles

	package RoboDog;

	use base 'Dog';

	Dog->does( 'Animal' );

=head1 DESCRIPTION

Class::Roles provides a Perl 5 implementation of Perl 6 roles.

Roles are named collections of reusable behavior.  They provide a mechanism to
mark that a class performs certain behaviors and to reuse the code that
performs those behaviors.

Polymorphism is a fundamental feature of object orientation.  It's important
that behaviors that are similar in a semantic sense but different in specific
details can be abstracted behind the same name.  A dog may sleep by turning in
circles three times then lying down while a cat may sprawl out across the
nearest human lap.  Both sleep, however.

Allomorphism -- polymorphic equivalence -- is a lesser-known feature.  This
suggests that objects with compatible behavior should be able to be treated
interchangeably.  A C<Dog> and a C<Lifeguard> may both understand the
C<rescue_drowning_swimmer> message, not because they share a common ancestor
class but because they share a role.

=head1 USAGE

=head2 Defining a Role

To define a role, define a package containing the methods that comprise that
role.  Pass these methods to C<Class::Roles>' C<import()> method via the
C<role> keyword.  For example, the C<Lifeguard> role may be:

	package Lifeguard;

	use Class::Roles role => 'rescue_drowning_swimmer', 'scan_ocean';

	sub rescue_drowning_swimmer
	{
		# implementation here
	}

	sub scan_ocean
	{
		# implementation here
	}

A C<Lifeguard> role will be declared, comprised of the
C<rescue_drowning_swimmer> and C<scan_ocean> methods.

=head2 Defining Multiple Roles in a Module

Use the C<multi> target to define multiple roles in a single module:

	package MultiRoles;

	sub drive_around   { ... }
	sub steering_wheel { ... }

	sub fly_around     { ... }
	sub yoke           { ... }

	use Class::Roles multi =>
	{
		car   => [qw( drive_around steering_wheel )],
		plane => [qw( fly_around   yoke           )],
	}

=head2 Performing a Role

Any class that performs a role should declare that it does so, via the C<does>
keyword to C<import()>:

	package Dog;

	use Class::Roles does => 'Lifeguard';

Any methods of the role that the performing class does not implement will be
imported.

As you'd expect, extending a class that performs a role means that the subclass
also performs that role.  Inheritance is just a specific case of role-based
systems.

=head2 Testing a Role

Use the C<does()> method to test that a class or object performs the named
role.

	my $dog = Dog->new();
	print "Can't help a drowning swimmer\n" unless $dog->does( 'Lifeguard' );

Use C<does()> instead of C<isa()> if allomorphism is important to you.

=over 4

=back

=head1 SEE ALSO

=over 4

=item * L<Class::ActsLike>, a less P6-ish approach

=item * Traits: Composable Units of Behavior

L<http://www.cse.ogi.edu/~black/publications/TR_CSE_02-012.pdf>

=item * Allomorphism at the Portland Pattern Repository

L<http://c2.com/cgi/wiki?AlloMorphism>

=back

=head1 AUTHOR

chromatic, C<chromatic@wgz.org>

=head1 BUGS

No known bugs.

=head1 TODO

=over 4

=item * better error checking

=item * keep up to date with Perl 6 syntax

=back

=head1 COPYRIGHT

Copyright (c) 2003, chromatic.  All rights reserved.  This module is
distributed under the same terms as Perl itself, in the hope that it is useful
but certainly under no guarantee.
