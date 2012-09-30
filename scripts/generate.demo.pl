#!/usr/bin/env perl

use strict;
use warnings;

use Date::Format; # For time2str.

use GraphViz2::Marpa::PathUtils;

use Text::Xslate 'mark_raw';

# -----------------------------------------------

my($input_file) = shift || die "Usage: $0 input_file";
my($templater)  = Text::Xslate -> new
(
  input_layer => '',
  path        => 'html',
);
my($count) = 0;
my($index) = $templater -> render
(
	'fixed.length.paths.tx',
	{
		date_stamp => time2str('%Y-%m-%d %T', time),
		input_file => $input_file,
		version    => $GraphViz2::Marpa::PathUtils::VERSION,
	}
);
my($file_name) = File::Spec -> catfile('html', 'fixed.length.paths.html');

open(OUT, '>', $file_name);
print OUT $index;
close OUT;

print "Wrote: $file_name. \n";
