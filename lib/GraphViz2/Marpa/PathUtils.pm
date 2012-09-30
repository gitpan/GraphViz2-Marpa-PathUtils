package GraphViz2::Marpa::PathUtils;

use parent 'GraphViz2::Marpa';
use strict;
use warnings;

use File::Which; # For which().

use Hash::FieldHash ':all';

use IPC::Run3; # For run3().

use Set::Array;

use Tree;

fieldhash my %allow_cycles    => 'allow_cycles';
fieldhash my %command         => 'command';
fieldhash my %dot_input       => 'dot_input';
fieldhash my %dot_output      => 'dot_output';
fieldhash my %driver          => 'driver';
fieldhash my %format          => 'format';
fieldhash my %path_length     => 'path_length';
fieldhash my %path_set        => 'path_set';
fieldhash my %report_paths    => 'report_paths';
fieldhash my %root            => 'root';
fieldhash my %start_node      => 'start_node';
fieldhash my %tree_dot_file   => 'tree_dot_file';
fieldhash my %tree_image_file => 'tree_image_file';

our $VERSION = '1.00';

# -----------------------------------------------
# Build a forest of nodes from the Graphviz file.

sub _build_tree
{
	my($self, $items) = @_;

	my(%node, $node);
	my($parent);
	my($value);

	for (my $i = 0; $i <= $#$items; $i++)
	{
		# Skip if not a node.

		next if ($$items[$i]{type} ne 'node_id');

		$value = $$items[$i]{value};

		if (! exists $node{$value})
		{
			$node{$value} = Tree -> new($value);
		}

		$node = $node{$value};

		# Is there room in the list for another edge and node? If not, skip.

		while ($i <= $#$items - 2)
		{
			$parent = $node;

			# Skip if the next element is not an edge.

			last if ($$items[$i + 1]{type} ne 'edge_id');

			# Skip if the next-but-1 element is not a node.

			last if ($$items[$i + 2]{type} ne 'node_id');

			$i     += 2;
			$value = $$items[$i]{value};
			$node  = Tree -> new($value);

			$parent -> add_child($node);
		}
	}

	$self -> root(\%node);

} # End of _build_tree.

# -----------------------------------------------

sub _find_fixed_length_candidates
{
	my($self, $solution, $stack) = @_;
	my($current_node) = $$solution[$#$solution];

	# Add the node's parent, if it's not the root.
	# Then add the node's children.

	my(@neighbours);

	$self -> traverse
	(
		sub
		{
			my($node) = @_;

			# We only want neighbours of the current node.
			# So, skip this node if:
			# o It is the root node.
			# o It is not the current node.

			return if ($node -> value ne $current_node -> value);

			# Now find its neighbours.

			my(@check) = $node -> children;

			push @check, $node -> parent if (! $node -> is_root);

			for my $n (@check)
			{
				push @neighbours, $n;
			}
		}
	);

	# Elements:
	# 0 .. N - 1: The neighbours.
	# N:          The count of neighbours.

	push @$stack, @neighbours, $#neighbours + 1;

} # End of _find_fixed_length_candidates.

# -----------------------------------------------
# Find all paths starting from any copy of the target start_node.

sub _find_fixed_length_path_set
{
	my($self, $start) = @_;
	my($one_solution) = [];
	my($stack)        = [];

	my(@all_solutions);
	my($count, $candidate);

	# Push the first copy of the start node, and its count (1), onto the stack.

	push @$stack, $$start[0], 1;

	# Process these N candidates 1-by-1.
	# The top-of-stack is a candidate count.

	while ($#$stack >= 0)
	{
		while ($$stack[$#$stack] > 0)
		{
			($count, $candidate) = (pop @$stack, pop @$stack);

			push @$stack, $count - 1;
			push @$one_solution, $candidate;

			# Does this candidate suit the solution so far?

			if ($#$one_solution == $self -> path_length)
			{
				# Yes. Save this solution.

				push @all_solutions, [@$one_solution];

				# Discard this candidate, and try another.

				pop @$one_solution;
			}
			else
			{
				# No. The solution is still too short.
				# Push N more candidates onto the stack.

				$self -> _find_fixed_length_candidates($one_solution, $stack);
			}
		}

		# Pop the candidate count (0) off the stack.

		pop @$stack;

		# Remaining candidates, if any, must be contending for the 2nd last slot.
		# So, pop off the node in the last slot, since we've finished
		# processing all candidates for that slot.
		# Then, backtrack to test the next set of candidates for what,
		# after this pop, will be the new last slot.

		pop @$one_solution;
	}

	$self -> path_set([@all_solutions]);

} # End of _find_fixed_length_path_set.

# -----------------------------------------------
# Find all paths starting from any copy of the target start_node.

sub _find_fixed_length_paths
{
	my($self) = @_;
	my($tree) = $self -> root;

	# Phase 1: Find all copies of the start node.

	my(@stack);

	$self -> traverse
	(
		sub
		{
			my($node) = @_;

			push @stack, $node if ($node -> value eq $self -> start_node);
		}
	);

	# Give up if the given node was not found.
	# Return 0 for success and 1 for failure.

	die 'Error: Start node (', $self -> start_node, ") not found\n" if ($#stack < 0);

	# Phase 2: Process each copy of the start node.

	$self -> _find_fixed_length_path_set(\@stack);

} # End of _find_fixed_length_paths.

# -----------------------------------------------

sub find_fixed_length_paths
{
	my($self) = @_;

	# Generate the RAM-based version of the graph.

	my($result) = $self -> run;

	$self -> log(info => "Result of calling lexer and parser: $result (0 is success)");

	# Assemble the nodes into a tree.

	my(@items) = @{$self -> parser -> items};

	$self -> _build_tree(\@items);

	# Process the tree.

	$self -> _find_fixed_length_paths;
	$self -> _winnow_fixed_length_paths;

	my($title) = 'Starting node: ' . $self -> start_node . "\\n" .
		'Path length: ' . $self -> path_length . "\\n" .
		'Allow cycles: ' . $self -> allow_cycles . "\\n" .
		'Solutions: ' . scalar @{$self -> path_set};

	$self -> _prepare_output($title);
	$self -> report_fixed_length_paths($title) if ($self -> report_paths);
	$self -> output_fixed_length_paths         if ($self -> tree_dot_file);
	$self -> output_fixed_length_image         if ($self -> tree_image_file);

	# Return 0 for success and 1 for failure.

	return 0;

} # End of find_fixed_length_paths.

# -----------------------------------------------

sub _init
{
	my($self, $arg)        = @_;
	$$arg{allow_cycles}    ||= 0;     # Caller can set.
	$$arg{command}         = Set::Array -> new;
	$$arg{dot_input}       = '';
	$$arg{dot_output}      = '';
	$$arg{driver}          ||= which('dot'); # Caller can set.
	$$arg{format}          ||= 'svg'; # Caller can set.
	$$arg{path_length}     ||= 0;     # Caller can set.
	$$arg{path_set}        = [];
	$$arg{report_paths}    ||= 0;     # Caller can set.
	$$arg{root}            = {};
	$$arg{start_node}      = defined($$arg{start_node}) ? $$arg{start_node} : undef; # Caller can set (to 0).
	$$arg{tree_dot_file}   ||= ''; # Caller can set.
	$$arg{tree_image_file} ||= ''; # Caller can set.
	$self                  = $self -> SUPER::_init($arg);

	die "Error: No start node specified\n"  if (! defined $self -> start_node);
	die "Error: Path length must be >= 0\n" if ($self -> path_length < 0);

	return $self;

} # End of _init.

# -----------------------------------------------

sub output_fixed_length_image
{
	my($self) = @_;

	if ($self -> input_file eq $self -> tree_image_file)
	{
		die "Error: Input file and tree image file have the same name. Refusing to overwrite the latter\n";
	}

	my($driver)     = $self -> driver;
	my($format)     = $self -> format;
	my($image_file) = $self -> tree_image_file;

	# This line has been copied from GraphViz2's run() method.
	# Except, that is, for the timeout, which is not used in GraphViz2 anyway.

	$self -> log(debug => "Driver: $driver. Output file: $image_file. Format: $format");

	my($stdout, $stderr);

	run3([$driver, "-T$format"], \$self -> dot_input, \$stdout, \$stderr);

	die "Error: $stderr" if ($stderr);

	$self -> dot_output($stdout);

	if ($image_file)
	{
		open(OUT, '>', $image_file) || die "Error: Can't open(> $image_file): $!";
		binmode OUT;
		print OUT $stdout;
		close OUT;

		$self -> log(notice => "Wrote $image_file. Size: " . length($stdout) . ' bytes');
	}

} # End of output_fixed_length_image.

# -----------------------------------------------

sub output_fixed_length_paths
{
	my($self) = @_;

	open(OUT, '>', $self -> tree_dot_file) || die "Error: Can't open(> ", $self -> tree_dot_file, "): $!\n";
	print OUT $self -> dot_input;
	close OUT;

	$self -> log(notice => 'Wrote ' . $self -> tree_dot_file . '. Size: ' . length($self -> dot_input) . ' bytes');

} # End of output_fixed_length_paths.

# -----------------------------------------------

sub _prepare_output
{
	my($self, $title) = @_;

	# We have to rename all the nodes so they can all be included
	# in a DOT file without dot linking them based on their names.

	my($new_name) = 0;

	my($name);
	my(@set);

	for my $set (@{$self -> path_set})
	{
		my(@name);
		my(%seen);

		for my $node (@$set)
		{
			$name = $node -> value;

			if (! defined($seen{$name}) )
			{
				$seen{$name} = ++$new_name;
			}

			push @name, {label => $name, name => $seen{$name} };
		}

		push @set, [@name];
	}

	# Now output the paths, using the nodes' original names as labels.

	my($graph) = qq|\tgraph [label = \"$title\" rankdir = LR];|;

	$self -> command -> push
	(
		'strict digraph',
		'{',
		$graph,
		''
	);

	for my $set (@set)
	{
		for my $node (@$set)
		{
			$self -> command -> push(qq|\t\"$$node{name}\" [label = \"$$node{label}\"]|);
		}
	}

	for my $set (@set)
	{
		$self -> command -> push("\t" . join(' -> ', map{qq|"$$_{name}"|} @$set) .";");
	}

	$self -> command -> push("}\n");
	$self -> dot_input(join("\n", @{$self -> command -> print}) );

} # End of _prepare_output.

# -----------------------------------------------

sub pretty_print
{
	my($self, $node) = @_;

	$self -> log(notice => '-' x 50);
	$self -> log(notice => 'Pretty-print the graph:');

	$self -> traverse
	(
		sub
		{
			my($node) = @_;

			$self -> log(notice => '   ' x $node -> depth . $node -> value);
		}
	);

	$self -> log(notice => '-' x 50);

} # End of pretty_print.

# -----------------------------------------------

sub report_fixed_length_paths
{
	my($self, $title) = @_;
	$title            =~ s/\\n/. /g;

	$self -> log(notice => "$title:");

	for my $candidate (@{$self -> path_set})
	{
		$self -> log(notice => join(' -> ', map{$_ -> value} @$candidate) );
	}

} # End of report_fixed_length_paths.

# -----------------------------------------------

sub traverse
{
	my($self, $sub, $print) = @_;
	my($tree) = $self -> root;

	for my $key (sort{$$tree{$a} -> value cmp $$tree{$b} -> value} keys %$tree)
	{
		for my $node ($$tree{$key} -> traverse($$tree{$key} -> PRE_ORDER) )
		{
			$sub -> ($node);
		}
	}

} # End of traverse.

# -----------------------------------------------

sub _winnow_fixed_length_paths
{
	my($self)   = @_;
	my($cycles) = $self -> allow_cycles;

	my(@solutions);

	for my $candidate (@{$self -> path_set})
	{
		# Count the number of times each node appears in this candidate.

		my(%seen);

		$seen{$_}++ for map{$_ -> value} @$candidate;

		# Exclude nodes depending on the allow_cycles option:
		# o 0 - Do not allow any cycles.
		# o 1 - Allow any node to be included once or twice.

		if ($cycles == 0)
		{
			@$candidate = grep{$seen{$_ -> value} == 1} @$candidate;
		}
		elsif ($cycles == 1)
		{
			@$candidate = grep{$seen{$_ -> value} <= 2} @$candidate;
		}

		push @solutions, [@$candidate] if ($#$candidate == $self -> path_length);
	}

	$self -> path_set([@solutions]);

} # End of _winnow_fixed_length_paths.

# -----------------------------------------------

1;

=pod

=head1 NAME

L<GraphViz2::Marpa::PathUtils> - Provide various analyses of Graphviz dot files

=head1 Synopsis

Perl usage:

Either pass parameters in to new():

	GraphViz2::Marpa::PathUtils -> new
	(
	    allow_cycles    => 1,
	    input_file      => 'data/90.KW91.gv',
	    path_length     => 4,
	    report_paths    => 1,
	    start_node      => 'Act_1',
	    tree_dot_file   => 'data/fixed.length.paths.gv',
	    tree_image_file => 'html/fixed.length.paths.svg',
	) -> find_fixed_length_paths;

Or call methods to set parameters;

	my($parser) = GraphViz2::Marpa::PathUtils -> new;

	$parser -> allow_cycles(1);
	$parser -> input_file('data/90.KW91.gv');
	$parser -> path_length(4);
	$parser -> report_paths(1);
	$parser -> start_node('Act_1');
	$parser -> tree_dot_file('data/fixed.length.paths.gv');
	$parser -> tree_image_file('html/fixed.length.paths.sgv');

	$parser -> find_fixed_length_paths;

Command line usage:

	shell> perl scripts/fixed.length.paths.pl -h

Or see scripts/fixed.length.paths.sh, which hard-codes my test data values.

All scripts and input and output files listed here are shipped with the distro.

=head1 Description

GraphViz2::Marpa::PathUtils parses L<Graphviz|http://www.graphviz.org/> dot files and processes the output in various ways.

This class is a descendent of L<GraphViz2::Marpa>, and hence inherits all its keys to new(), and all its methods.

Currently, the only feature available is to find all paths of a given length starting from a given node.

Sample output: L<http://savage.net.au/Perl-modules/html/graphviz2.marpa/fixed.length.paths.html>.

Note: This version of the code ignores the directions of the edges, meaning all input graphs are assumed
to be undirected.

=head1 Scripts shipped with this distro

All scripts are in the scripts/ directory. This means they do I<not> get installed along with the package.

Data files are in data/, while html and svg files are in html/.

=over 4

=item o fixed.length.paths.pl

This runs the find_fixed_length_paths() method in GraphViz2::Marpa::PathUtils.

Try shell> perl fixed.length.paths.pl -h

=item o fixed.length.paths.sh

This runs fixed.length.paths.pl with hard-coded parameters, and is what I use for testing new code.

Then it runs generate.demo.pl.

Lastly it copies the output to my web server's doc root, called $DR.

=item o generate.demo.pl

This uses the L<Text::Xslate> template file html/fixed.length.paths.tx to generate fixed.length.paths.html.

=back

See also t/fixed.length.paths.t.

=head1 Distributions

This module is available as a Unix-style distro (*.tgz).

See L<http://savage.net.au/Perl-modules/html/installing-a-module.html>
for help on unpacking and installing distros.

=head1 Installation

Install L<GraphViz2::Marpa::PathUtils> as you would for any C<Perl> module:

Run:

	cpanm GraphViz2::Marpa::PathUtils

or run:

	sudo cpan GraphViz2::Marpa::PathUtils

or unpack the distro, and then either:

	perl Build.PL
	./Build
	./Build test
	sudo ./Build install

or:

	perl Makefile.PL
	make (or dmake or nmake)
	make test
	make install

=head1 Constructor and Initialization

=head2 Calling new()

C<new()> is called as C<< my($obj) = GraphViz2::Marpa::PathUtils -> new(k1 => v1, k2 => v2, ...) >>.

It returns a new object of type C<GraphViz2::Marpa::PathUtils>.

This class is a descendent of L<GraphViz2::Marpa>, and hence inherits all its keys to new(), and all its methods.

Further, these key-value pairs are accepted in the parameter list (see corresponding methods for details
[e.g. L</path_length($integer)>]):

=over 4

=item o allow_cycles => $integer

Specify whether or not cycles are allowed in the paths found.

Values for $integer:

=over 4

=item o 0 - Do not allow any cycles

This is the default.

=item o 1 - Allow any node to be included once or twice.

=back

Default: 0.

=item o driver => thePathToDot

Specify the OS's path to the I<dot> program, to override the default.

Default: Use which('dot'), via the module L<File::Which>, to find the I<dot> executable.

=item o format => $aDOTOutputImageFormat

Specify the image type to pass to I<dot>, as the value of dot's -T option.

Default: 'svg'.

=item o path_length => $integer

Specify the length of all paths to be included in the output.

Here, length means the number of edges between nodes.

Default: 0.

This parameter is mandatory, and must be > 0.

=item o report_paths => $Boolean

Specify whether or not to print a report of the paths found.

Default: 0 (do not print).

=item o start_node => $theNameOfANode

Specify the name of the node where all paths must start from.

Default: ''.

This parameter is mandatory.

The name can be the empty string, but must not be undef.

=item o tree_dot_file => aDOTInputFileName

Specify the name of a file to write which will contain the DOT description of the image of all solutions.

Default: ''.

This file is not written if the value is ''.

=item o tree_image_file => aDOTOutputFileName

Specify the name of a file to write which will contain the output of running I<dot>.

The value of the I<format> option determines what sort of image is created.

Default: ''.

This file is not written if the value is ''.

=back

=head1 Methods

This class is a descendent of L<GraphViz2::Marpa>, and hence inherits all its methods.

Further, these methods are implemented.

=head2 allow_cycles([$integer])

Here the [] indicate an optional parameter.

Get or set the value determining whether or not cycles are allowed in the paths found.

'allow_cycles' is a parameter to L</new()>. See L</Constructor and Initialization> for details.

=head2 command()

Returns an object of type L<Set::Array> where each element is a line of text to be output to a DOT
file. The string obtained by combining these elements is returned by L</dot_input()>.

You would normally never call this method.

=head2 dot_input()

Returns the string which will be input to the I<dot> program.

=head2 dot_output()

Returns the string which has been output by the I<dot> program.

=head2 driver([$pathToDot])

Here the [] indicate an optional parameter.

Get or set the OS's path to the I<dot> program.

=head2 find_fixed_length_paths()

This is the method which does all the work, and hence must be called.

See the L</Synopsis> and scripts/fixed.length.paths.pl.

Returns 0 for success and 1 for failure.

=head2 format([$string])

Here the [] indicate an optional parameter.

Get or set the type of image to be output when running I<dot>.

'format' is a parameter to L</new()>. See L</Constructor and Initialization> for details.

=head2 new()

See L</Constructor and Initialization> for details on the parameters accepted by L</new()>.

=head2 output_fixed_length_image($title)

This writes the paths found, as a DOT output file, as long as new(tree_image_file => $name) was specified,
or if tree_image_file($name) was called before L</find_fixed_length_paths()> was called.

=head2 output_fixed_length_paths($title)

This writes the paths found, as a DOT input file, as long as new(tree_dot_file => $name) was specified,
or if tree_dot_file($name) was called before L</find_fixed_length_paths()> was called.

=head2 path_length([$integer])

Here the [] indicate an optional parameter.

Get or set the length of the paths to be searched for.

'path_length' is a parameter to L</new()>. See L</Constructor and Initialization> for details.

=head2 path_set()

Returns the arrayref of paths found. Each element is 1 path, and paths are stored as an arrayref of
objects of type L<Tree>.

See the source code of sub L</report_fixed_length_paths()> for sample usage.

=head2 report_fixed_length_paths()

This prints the paths found, as long as new(report_paths => 1) was specified, or if
report_paths(1) was called before L</find_fixed_length_paths()> was called.

=head2 report_paths([$Boolean])

Here the [] indicate an optional parameter.

Get or set the option which determines whether or not the paths found are printed.

'report_paths' is a parameter to L</new()>. See L</Constructor and Initialization> for details.

=head2 start_node([$string])

Here the [] indicate an optional parameter.

Get or set the name of the node from where all paths must start.

'start_node' is a parameter to L</new()>. See L</Constructor and Initialization> for details.

=head2 tree_dot_file([$name])

Here the [] indicate an optional parameter.

Specify the name of the I<dot> input file to write.

'tree_dot_file' is a parameter to L</new()>. See L</Constructor and Initialization> for details.

=head2 tree_image_file([$name])

Here the [] indicate an optional parameter.

Specify the name of the I<dot> output file to write.

The type of image comes from the I<format> parameter to new(), or from calling L</format($string)>
before L</find_fixed_length_paths()> is called.

'tree_image_file' is a parameter to L</new()>. See L</Constructor and Initialization> for details.

=head1 FAQ

=head2 Why do I get error messages like the following?

	Error: <stdin>:1: syntax error near line 1
	context: digraph >>>  Graph <<<  {

Graphviz reserves some words as keywords, meaning they can't be used as an ID, e.g. for the name of the graph.
So, don't do this:

	strict graph graph{...}
	strict graph Graph{...}
	strict graph strict{...}
	etc...

Likewise for non-strict graphs, and digraphs. You can however add double-quotes around such reserved words:

	strict graph "graph"{...}

Even better, use a more meaningful name for your graph...

The keywords are: node, edge, graph, digraph, subgraph and strict. Compass points are not keywords.

See L<keywords|http://www.graphviz.org/content/dot-language> in the discussion of the syntax of DOT
for details.

=head2 The number of options is confusing!

Agreed. Remember that this code calls L<GraphViz2::Marpa>'s run() method, which expects a large number of
options because it calls both the lexer and the parser.

The options used only by this code are listed under L</Calling new()>.

The methods used only by this code, which are not options, are:

=over 4

=item o L</command()>

=item o L</dot_input()>

=item o L</dot_output()>

=item o L</path_set()>

=back

=head2 Isn't your code at risk from the 'combinatorial explosion' problem?

Yes. The code does limit the number of possibilies as quickly as possible, but of course there will always be
graphs which can't be processed by this module.

Such graphs are deemed to be pathological.

=head2 How are cycles in the graph handled?

This is controlled by the I<allow_cycles> option to new(), or the corresponding method L</allow_cycles($integer)>.

The code keeps track of the number of times each node is entered. If new(allow_cycles => 0) was called,
nodes are only considered if they are entered once. If new(allow_cycles => 1) was called, nodes are also
considered if they are entered a second time.

Sample code: Using the input file data/90.KW91.lex (see scripts/fixed.length.paths.sh) we can specify
various combinations of parameters like this:

	allow_cycles  path_length  start node  solutions
	0             3            Act_1       9
	1             3            Act_1       22

	0             4            Act_1       12
	1             4            Act_1       53

=head2 Are all paths found unique?

Yes, as long as they are unique in the input. Something like this produces 8 identical solutions
(starting from A, of path length 3) because each node B, C, D, can be entered in 2 different ways,
and 2**3 = 8.

	digraph G
	{
	    A -> B -> C -> D;
	    A -> B -> C -> D;
	}

See data/non.unique.gv and html/non.unique.svg.

=head1 Reference

Combinatorial Algorithms for Computers and Calculators, A Nijenhuis and H Wilf, p 240.

This books very clearly explains the backtracking parser I used to process the combinations of nodes found
at each point along each path. Source code in the book is in Fortran.

The book is now downloadable as a PDF from L<http://www.math.upenn.edu/~wilf/website/CombAlgDownld.html>.

=head1 TODO

=over 4

=item o Take into account the graph/digraph nature of the graph

=item o Implement logic to end paths on a given node

=back

=head1 Version Numbers

Version numbers < 1.00 represent development versions. From 1.00 up, they are production versions.

=head1 Machine-Readable Change Log

The file CHANGES was converted into Changelog.ini by L<Module::Metadata::Changes>.

=head1 Support

Email the author, or log a bug on RT:

L<https://rt.cpan.org/Public/Dist/Display.html?Name=GraphViz2::Marpa::PathUtils>.

=head1 Author

L<GraphViz2::Marpa::PathUtils> was written by Ron Savage I<E<lt>ron@savage.net.auE<gt>> in 2012.

Home page: L<http://savage.net.au/index.html>.

=head1 Copyright

Australian copyright (c) 2012, Ron Savage.

	All Programs of mine are 'OSI Certified Open Source Software';
	you can redistribute them and/or modify them under the terms of
	The Artistic License, a copy of which is available at:
	http://www.opensource.org/licenses/index.html

=cut
