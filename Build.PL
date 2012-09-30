use Module::Build;

if (open my $fh, '|dot', )
{
	close $fh;
}
else
{
	die "Please install Graphviz from http://www.graphviz.org/.\n";
}

Module::Build -> new
(
module_name    => 'GraphViz2::Marpa::PathUtils',
license        => 'artistic',
dist_abstract  => 'Provide various analyses of Graphviz dot files',
dist_author    => 'Ron Savage <ron@savage.net.au>',
build_requires =>
{
	Test::More => 0.98,
	Test::Pod  => 1.44,
},
configure_requires =>
{
	Module::Build => 0.3800,
},
requires =>
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
	Tree             => 1.01,
	Text::Xslate     => 1.4001,
	warnings         => 1.03,
},
) -> create_build_script();
