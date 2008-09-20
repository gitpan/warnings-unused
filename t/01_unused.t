#!perl

use constant HAS_STATE => eval q{ use feature 'state'; 1 };

use strict;
use Test::More tests => 12;
use Test::Warn;
use constant WARN_PAT => qr/Unused variable (?:my|state) [\$\@\%]\w+/;

use Errno (); # preload for Devel::Cover

use warnings::unused;
use warnings;


sub my_eval{
	my($s) = @_;

	eval qq{$s; warnings::unused::flush(); };
}

warning_like { my_eval q{ my $var; } } WARN_PAT, 'unused var';
warning_like { my_eval q{ my $var; $var++ } } [], 'used var';

warning_like{ my_eval q{ my $var; { my $var; $var++ }; } } WARN_PAT, 'scope';

warning_like{ my_eval q{ my $var; return sub{ $var } } } [], 'closure';

warning_like { my_eval q{ my @ary; } } WARN_PAT, 'unused var';
warning_like { my_eval q{ my @ary; push @ary, 1 } } [], 'used var';


warning_like { my_eval q{ my %hash; } } WARN_PAT, 'unused hash ';
warning_like { my_eval q{ my %hash; $hash{hoge}++ } } [], 'used hash';

warning_like { my_eval q{
	my $foo;
	sub foo{
		my($self, $var) = @_;
		$var++;
	}
	$foo++;
}} WARN_PAT, 'in sub';


warning_like { my_eval q{ our $var; } } [], 'our var';

SKIP:{
	skip q{use feature 'state'}, 1 unless HAS_STATE;
	warning_like { my_eval q{ use feature 'state'; state $var; } } WARN_PAT, 'state var';
}

warning_like {
	my_eval q{ no warnings 'unused'; my $unused_but_not_complained; }
} [], 'unused but not complained';
