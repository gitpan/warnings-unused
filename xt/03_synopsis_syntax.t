#!perl -w

use strict;
use Test::More tests => 1;

use warnings::unused ();

my $content = do{
	local $/;
	open my $in, '<', $INC{'warnings/unused.pm'};
	<$in>;
};

my($synopsis) = $content =~ m{
	^=head1 \s+ SYNOPSIS
	(.+)
	^=head1 \s+ DESCRIPTION
}xms;

no warnings 'once';
ok eval("sub{ $synopsis }"), 'syntax ok' or diag $@;
