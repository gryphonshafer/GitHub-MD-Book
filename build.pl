#!/usr/bin/env perl

=head1 NAME

build.pl - Build Markdown and HTML book files from Markdown source files

=head1 SYNOPSIS

    build.pl [CONFIGURATION_SETTINGS_YAML_FILE] [WORKSPACE_ROOT]
        -h, --help
        -m, --man

=head1 DESCRIPTION

This program will build Markdown and HTML book files from Markdown source
files. Given a C<WORKSPACE_ROOT> directory (which will default to the current
working directory if not specified), this program will search for Markdown
source files and build output files based on C<CONFIGURATION_SETTINGS_YAML_FILE>
settings. If no settings file is provided, the program will assume defaults.

For example:

    ./build.pl configuration_settings_yaml_file.yaml `pwd`

You can view a simple usage help message via:

    ./build.pl --help

You can view a manual page via:

    ./build.pl --man

=head2 Configuration Settings YAML File

The build configuration settings YAML file contains the setting for any number
of build runs. It can also contain a C<defaults> section for default settings
that can be overriden in any specific build.

For example:

    defaults:
        workspace: .
        cover: true
        toc: true
        encoding: utf-8
        directory: output
        basename: build
    builds:
      - workspace: book
        basename: book
      - workspace: booklet
        basename: booklet
        cover: false
        toc: false
        env:
            build_msg: Build Message

=head3 workspace

This is a directory that represents the top-level directory of a project
workspace, which will be searched in depth to find all files with the "md"
suffix. These files will be read in sort order to form the source markdown
content.

=head3 filter

One or more sections (defined by header text) can be filtered using this option.
Filtered sections are removed throughout the source material, regardless of
their starting header level. The sections end upon the next header, regardless
of that header's level.

=head3 append

One or more sections (defined by header text) can be copied and appended to the
end of the source material, much like an appendix.

=head3 build_date

Date format to use to create a "build_date" environment variable for
substitutions. The default is: "%Y-%m-%d %H:%M:%S %Z"

=head3 numerate

If this flag is set, headers (other than the cover page header) will be
numerated; meaning it will be given a number associated with its outline
location. For example, if a header is a level 2 header, it might render as:

    ## 3.7 Header

=head3 cover

If this flag is set, the source content from the first header through to the
next header, regardless of header levels, will be considered content for a cover
page in all but the markdown outputs. It will be wrapped at the HTML stage in
a section tag with "cover" as ID:

    <section id="cover">...</section>

=head3 toc

If this flag is set, a table of contents will be generated for all outputs other
than markdown based on the headers of the source content (excluding the cover
page if that flag is set). A section will be added to the document with the
following structure:

    <section id="toc">
        <h1>Table of Contents</h1>
        <ul>
            <li><a href="#header">Header</li>
        </ul>
    </section>

=head3 remove_terms

If this flag is set, any terms/definitions found in the markdown source content
will be removed.

=head3 glossary

If this flag is set, any terms/definitions found in the markdown source content
will be appended as a glossary.

=head3 language

This is the language set in the HTML. The default is "en-us".

=head3 encoding

This is the encoding set in the HTML and the encoding of the HTML output. The
default is "utf-8".

=head3 directory

This option sets the output directory. If the directory does not exist, it will
be created. The default is "output".

=head3 basename

This option sets the output basename. The default is "output", meaning that the
HTML output will be saved to "output.html" by default.

=head3 types

One or more output types can be set using this option. If this option is not
specified, all outputs are set for types. The type options available are:
MD and HTML.

=head3 insert

This option sets the file of assumed to be HTML header content to insert into
the header section of the HTML generated output. The default is: "header.html".

=head3 style

This option sets the file of assumed to be CSS content to insert into the
header section of the HTML generated output. The default is: "style.css".

=head3 paged

This option if set will result in an output file with name suffix ".paged.html"
to be generated. This file is intended to be viewed in a browser to preview
what a printed paged document should look like.

=head3 quiet

This option if set will silence progress reports.

=head3 env

Case-insensitive environment variable substitutions are supported and are
represented in the markdown source with a leading C<$>. For example:

    $example

This above will be replaced with any environment variable case-insensitively
matching "example".

=cut

use exact -cli, -me;
use Cwd 'cwd';
use Date::Format 'time2str';
use Encode 'decode';
use IPC::Run qw( run timeout );
use Mojo::ByteStream;
use Mojo::DOM;
use Mojo::File 'path';
use Text::MultiMarkdown 'markdown';
use YAML::XS;

podhelp;

my ( $settings_yaml, $workspace_root ) = @ARGV;
$workspace_root = path( $workspace_root // cwd );
my $assets_root = path(me);

my $settings;
try {
    $settings = YAML::XS::Load( decode( 'UTF-8', $workspace_root->child($settings_yaml)->slurp ) );
}
catch {}

my $time   = time;
my $builds = [
    map {
        my $build = $_;

        $build->{workspace} = ( $build->{workspace} )
            ? $workspace_root->child( $build->{workspace} )
            : $workspace_root;
        $build->{insert} = ( $build->{insert} )
            ? $build->{workspace}->child( $build->{insert} )
            : $assets_root->child('header.html');
        $build->{style} = ( $build->{style} )
            ? $build->{workspace}->child( $build->{style} )
            : $assets_root->child('style.css');

        for ( qw( workspace insert style ) ) {
            croak(qq{"$_" location not readable}) unless ( -r $build->{workspace} )
        }

        $build->{directory} = $workspace_root->child( $build->{directory} // 'output' );
        croak( 'Unable to create directory: ' . $build->{directory}->to_string )
            unless( -d $build->{directory}->make_path );

        $build->{language}   ||= 'en-us';
        $build->{encoding}   ||= 'utf-8';
        $build->{basename}   ||= 'output';
        $build->{build_date} ||= '%Y-%m-%d %H:%M:%S %Z';

        $build->{types} = [ qw( md html ) ] unless ( $build->{types} and @{ $build->{types} } );

        my $vars = {
            %ENV,
            %{
                ( $settings->{defaults} and $settings->{defaults}{env} )
                    ? $settings->{defaults}{env}
                    : {}
            },
            %{ $build->{env} // {} },
        };
        $vars->{build_date} = time2str( $build->{build_date}, $time );
        $vars->{build_time} = $time;

        $build->{env} = { map {
            chomp $vars->{$_};
            my $name = lc $_;
            (
                $name            => $vars->{$_},
                $name . '_short' => substr( $vars->{$_}, 0, 7 ),
            );
        } keys %$vars };

        $build;
    }
    ( $settings->{defaults} )
        ? ( map { +{ %{ $settings->{defaults} }, %$_ } } @{ $settings->{builds} // [{}] } )
        : @{ $settings->{builds} // [{}] }
];

for my $opt (@$builds) {
    say 'Load all source input' unless ( $opt->{quiet} );
    my $md = $opt->{workspace}
        ->list_tree->grep( qr/(?<!README)\.md$/ )->sort->map('slurp')
        ->join("\n")->decode->to_string;
    $md =~ s/\r\n/\n/g;
    $md =~ s/\$(\w+)/ ( exists $opt->{env}{$1} ) ? $opt->{env}{$1} : "\$$1" /gei;

    say 'Read content sections' unless ( $opt->{quiet} );
    my $blocks = {};
    for my $name ( map { lc } @{ $opt->{append} || [] } ) {
        while ( $md =~ /^\s*(#+[ \t]*$name\s.*?)(?=\n[ \t]*#)/imsg ) {
            my $block = $1;
            unless ( $blocks->{$name} ) {
                $block =~ s/^\s*#+/#/;
            }
            else {
                $block =~ s/^\s*#+\N+\n//;
            }
            $blocks->{$name} .= $block;
        }
    }

    for ( map { lc } @{ $opt->{filter} || [] } ) {
        say 'Filter section: ' . $_ unless ( $opt->{quiet} );
        $md =~ s/^\s*#+[ \t]*$_\s.*?(?=\n[ \t]*#)//imsg;
    }

    my $terms = [];
    while ( $md =~ /^([ \t]*[^\n:]+[ \t]*\n[ \t]*:[ \t]*.+?)\n\n/msg ) {
        my $term_block = $1;
        push( @$terms, $term_block ) unless ( $term_block =~ /^\W*Term\W*:\s*Definition\b/i );
    }

    if ( $opt->{remove_terms} ) {
        say 'Remove terms' unless ( $opt->{quiet} );
        $md =~ s/^([ \t]*[^\n:]+[ \t]*\n[ \t]*:[ \t]*.+?)\n\n//msg;
    }

    if ( $opt->{glossary} and @$terms ) {
        say 'Add glossary of terms' unless ( $opt->{quiet} );
        $md .= "\n# Glossary\n\n" . join( "\n\n", sort @$terms );
    }

    if ( my @sections = map { lc } @{ $opt->{append} || [] } ) {
        say 'Append: ' . join( ', ', @sections ) unless ( $opt->{quiet} );
        $md .= "\n" . join( "\n\n", map { $blocks->{$_} } @sections );
    }

    if ( $opt->{numerate} ) {
        my %header_level;
        my $first_header_seen;
        my $headers = sub ($level) {
            delete $header_level{$_} for ( grep { $_ > $level } keys %header_level );

            if ( $opt->{cover} and not $first_header_seen ) {
                $first_header_seen = 1;
                return '';
            }

            $header_level{$level}++;
            return '' unless ( $header_level{1} );
            return ' ' . join( '', map { $header_level{$_} . '.' } 1 .. $level );
        };

        $md =~ s/^(\s*)(#+)/ $1 . $2 . $headers->( length($2) ) /mge;
    }

    my $dom   = Mojo::DOM->new( markdown($md) );
    my $title = $dom->at('h1') && $dom->at('h1')->all_text || 'Untitled';

    my $header_count;
    $dom->find('h1, h2, h3, h4, h5, h6')->each( sub {
        $_->attr( id => join( '_', $_->tag, ++$header_count, $_->attr('id') ) );
    } );

    my $spurt = sub ( $content, $file_suffix, $file_suffix_display = undef ) {
        $content =~ s|\$build_file\b| $opt->{basename} . ( $file_suffix_display // $file_suffix ) |gei;

        my $file = $opt->{directory}->child( $opt->{basename} . $file_suffix );
        $file->spurt( Mojo::ByteStream->new($content)->encode( $opt->{encoding} ) );

        push(
            @{ $settings->{releases}{assets} },
            (
                ($file_suffix_display)
                   ? $opt->{directory}->child( $opt->{basename} . $file_suffix_display )
                    : $file
            ),
        );
    };

    if ( grep { /^md$/i } @{ $opt->{types} } ) {
        say 'Write markdown output' unless ( $opt->{quiet} );
        $spurt->( $md, '.md' );
    }

    my $cover_content;
    if ( $opt->{cover} ) {
        say 'Select content for cover' unless ( $opt->{quiet} );

        my @nodes = $dom->at('h1, h2, h3, h4, h5, h6');
        while ( my $node = $nodes[-1]->next_node ) {
            last if ( $node->tag and $node->tag =~ /^h\d$/ );
            push( @nodes, $node );
        }
        $cover_content = join( '',
            '<section id="cover">',
            ( map { $_->remove; $_->to_string } @nodes ),
            '</section>',
        );
    }

    if ( $opt->{toc} ) {
        say 'Generate table of contents' unless ( $opt->{quiet} );
        $dom->prepend_content( join( '',
            '<section id="toc">',
            '<h1>Table of Contents</h1>',
            markdown(
                $dom->find('h1, h2, h3, h4, h5, h6')->map( sub {
                    ( ' ' x 4 ) x ( substr( $_->tag, 1 ) - 1 ) .
                        '- [' . $_->text . '](#' . $_->attr('id') . ')'
                } )->join("\n")->to_string
            ),
            '</section>',
        ) );
    }

    if ($cover_content) {
        say 'Prepend cover content' unless ( $opt->{quiet} );
        $dom->prepend_content($cover_content);
    }

    my $html = join( "\n",
        q{<!doctype html>},
        q{<html lang="} . $opt->{language} . q{">},
        q{    <head>},
        q{        <title>} . $title . q{</title>},
        q{        <meta charset="} . $opt->{encoding} . q{">},
        $opt->{insert}->slurp,
        q{        <style>},
        $opt->{style}->slurp,
        q{        </style>},
        q{    </head>},
        q{    <body>},
        $dom->to_string,
        q{    </body>},
        q{</html>},
    );

    if ( grep { /^html$/i } @{ $opt->{types} } ) {
        say 'Write HTML output' unless ( $opt->{quiet} );
        $spurt->( $html, '.html' );
    }

    if ( $opt->{paged} ) {
        $dom = Mojo::DOM->new($html);
        $dom->at('body')->append_content(
            '<script>document.getElementsByTagName("body")[0].style.margin = "0px"</script>'
        );

        say 'Write paged preview HTML output' unless ( $opt->{quiet} );
        $dom->at('body')
            ->append_content(q{
                <script src="https://unpkg.com/pagedjs/dist/paged.polyfill.js"></script>
            });

        $spurt->( $dom->to_string, '.paged.html' );
    }
}
