#!perl -w
use strict;
use warnings::unused;
use warnings;

my $a_unused = 42; # unused

sub foo{
	{
		my $a; # ok
		$a++;

	}

	my @bar = (2);

	my %baz = (foo => 0);

	my %b_unused;

	if($baz{foo}++){
		my $c_unused = sub{ @bar };

	}

	return my $d_unused = 10;

}

{
	no warnings 'unused';
	my $xyz; # unused but 'unused' is disabled
}
