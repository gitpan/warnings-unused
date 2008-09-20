use strict;
use warnings;
use inc::Module::Install;

name 'warnings-unused';

all_from 'unused.pm';

test_requires 'Test::Warn' => 0.11;


WriteMakefile(
	clean => {FILES => q{warnings-unused-*
				*.gcov *.gcda *.gcno
				*.stackdump cover_db}
		},
);
