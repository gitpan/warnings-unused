use 5.008_001;
use strict;
use warnings;
use inc::Module::Install;

name 'warnings-unused';

all_from 'unused.pm';

requires 'XSLoader'   => 0.06;

#recommends perl => '5.10.0';

test_requires 'Test::More' => 0.62;
test_requires 'Test::Warn' => 0.11;
#include_deps 'Test::Warn';

WriteMakefile(
	clean => {FILES => q{warnings-unused-*
				*.gcov *.gcda *.gcno
				*.stackdump cover_db}
		},
);
