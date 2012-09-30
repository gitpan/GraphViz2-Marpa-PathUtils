#!/bin/bash

FILE=90.KW91
NODE=Act_1

perl -Ilib scripts/fixed.length.paths.pl -input data/$FILE.gv \
	-tree_dot data/fixed.length.paths.gv -tree_image html/fixed.length.paths.svg \
	-report_paths 1 -allow_cycles 0 -path_length 3 -start_node $NODE

perl -Ilib scripts/generate.demo.pl $FILE.svg

cp html/fixed.length.paths.html $DR/Perl-modules/html/graphviz2.marpa/
cp html/$FILE.svg               $DR/Perl-modules/html/graphviz2.marpa/
cp html/fixed.length.paths.svg  $DR/Perl-modules/html/graphviz2.marpa/