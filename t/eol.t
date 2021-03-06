use Test2::V0;
use Test::EOL;
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
        eol_unix_ok( $_, { trailing_whitespace => 1 } );
    } );

done_testing;
