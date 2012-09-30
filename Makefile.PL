use ExtUtils::MakeMaker;

if (open my $fh, '|dot', )
{
	close $fh;
}
else
{
	die "Please install Graphviz from http://www.graphviz.org/.\n";
}

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile
(
($] ge '5.005') ?
(
 AUTHOR   => 'Ron Savage (ron@savage.net.au)',
 ABSTRACT => 'Provide various analyses of Graphviz dot files',
   ) : (),
clean =>
{
	FILES => 'blib/* Makefile MANIFEST GraphViz2-Marpa-PathUtils-*'
},
dist =>
{
	COMPRESS => 'gzip',
	SUFFIX   => 'gz'
},
DISTNAME  => 'GraphViz2-Marpa-PathUtils',
NAME      => 'GraphViz2::Marpa::PathUtils',
PL_FILES  => {},
PREREQ_PM =>
{
	Capture::Tiny    => 0.10,
	Date::Format     => 2.24,
	File::Which      => 1.09,
	GraphViz2::Marpa => 1.04,
	Hash::FieldHash  => 0.10,
	IPC::Run3        => 0.045,
	parent           => 0.225,
	Pod::Usage       => 1.36,
	Set::Array       => 0.26,
	strict           => 1.03,
	Test::More       => 0.98,
	Test::Pod        => 1.44,
	Text::Xslate     => 1.4001,
	Tree             => 1.01,
	warnings         => 1.03,
},
VERSION_FROM => 'lib/GraphViz2/Marpa/PathUtils.pm',
);
