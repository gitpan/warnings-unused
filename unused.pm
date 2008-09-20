package warnings::unused;

use 5.008_001;

use strict;
use warnings;

our $VERSION = '0.001';


{
	# register 'unused', rather than 'warnings::unused'
	package # hidden from CPAN indexer
		unused;
	use warnings::register;
}

use XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

1;
__END__

=head1 NAME

warnings::unused - Produces warnings when unused variables are detected

=head1 VERSION

This document describes warnings::unused version 0.001

=head1 SYNOPSIS

	use warnings::unused;
	use warnings;

	# WARN: Unused variable my $x
	sub foo{
		my($x, $y) = @_;

		return $y * 2;
	}


=head1 DESCRIPTION

This pragmatic module extends lexical warnings.

It produces warnings when a C<my> variable or C<state> variable is unused aside
from its declaration.

Given you write a subroutine like this:

	sub f{
		my($x, $y, $z) = @_;
		$y++;             # used
		return sub{ $z }; # used
	}

The code above is complained about C<$x>, because C<$x> is used nowhere
aside from its declaration.

You should write C<f()> like this:

	sub f{
		my(undef, $y, $z) = @_;
		$y++;             # used
		return sub{ $z }; # used
	}

Here, one will see the obvious intention to ignore the first argument of
C<f()>.

=head1 INTERFACE

=head2 C<use/no warnings 'unused';>

Enables/Disables the C<unused> warnings.

=head1 DEPENDENCIES

Perl 5.10.0 or later, and a C compiler.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-warnings-unused@rt.cpan.org/>, or through the web interface at
L<http://rt.cpan.org/>.

Patches are welcome.

=head1 SEE ALSO

L<perllexwarn>.

L<warnings::method>.

L<B::Lint>.

L<Perl::Critic>.

=head1 AUTHOR

Goro Fuji E<lt>gfuji(at)cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2008, Goro Fuji E<lt>gfuji(at)cpan.orgE<gt>. Some rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
