use Test2::V0;
use Test::NoTabs;
use Mojo::File 'path';
use Text::Gitignore 'build_gitignore_matcher';
use exact -me;

chdir( me('..') );

my $matcher = build_gitignore_matcher( [
    '.git', map { s|^/|./|; $_ } split( "\n", path('.gitignore')->slurp )
] );

path('.')
    ->list_tree({ hidden => 1 })
    ->grep( sub { not /\.pdf$/ } )
    ->map( sub { './' . $_->to_rel } )
    ->grep( sub { -f $_ and -T $_ and not $matcher->($_) } )
    ->each( sub {
        notabs_ok($_);
    } );

done_testing;
