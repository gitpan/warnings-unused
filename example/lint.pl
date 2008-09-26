#!perl -w
# A simple module lint program
# Usage: unused.pl MODULE1, MODULE2 ...

use strict;
use Module::Load;

use warnings::unused -global;

eval{ require warnings::method }; # optional

load($_) for @ARGV;
