#!/usr/bin/env perl

use strict;
use warnings;

use Capture::Tiny 'capture';

use GraphViz2::Marpa::PathUtils;

use Test::More;

# -------------

sub run
{
	GraphViz2::Marpa::PathUtils -> new
	(
		input_file   => 'data/90.KW91.gv',
		report_paths => 1,
		start_node   => 'Act_1',
		path_length  => 3,
	) -> find_fixed_length_paths;
}

# -------------

my($stdout, $stderr) = capture \&run;
my($expected)        = <<'EOS';
Starting node: Act_1. Path length: 3. Allow cycles: 0. Solutions: 9:
Act_1 -> Act_23 -> Act_25 -> Act_3
Act_1 -> Act_23 -> Act_25 -> Act_24
Act_1 -> Act_23 -> Act_24 -> Ext_3
Act_1 -> Act_23 -> Act_24 -> Act_25
Act_1 -> Act_23 -> Act_24 -> Act_22
Act_1 -> Act_23 -> Act_22 -> Act_24
Act_1 -> Act_23 -> Act_22 -> Act_21
Act_1 -> Act_21 -> Act_22 -> Act_24
Act_1 -> Act_21 -> Act_22 -> Act_23
EOS

ok($stdout eq $expected);

my($test_count) = 1;

done_testing($test_count);

__END__
