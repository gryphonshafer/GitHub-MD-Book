# GitHub MD Book

[![test](https://github.com/gryphonshafer/GitHub-MD-Book/workflows/test/badge.svg)](https://github.com/gryphonshafer/GitHub-MD-Book/actions?query=workflow%3Atest)
[![codecov](https://codecov.io/gh/gryphonshafer/GitHub-MD-Book/graph/badge.svg)](https://codecov.io/gh/gryphonshafer/GitHub-MD-Book)

This is a GitHub Action to build Markdown and HTML book files from Markdown
source files. To use, setup a workflow under the project's `.github/workflows`
directory. The following is an example for a `~/.github/workflows/release.yml`
file.

    name: release
    on: [ push, pull_request, workflow_dispatch ]
    jobs:
      build:
        runs-on: ubuntu-latest
        steps:
          - uses: actions/checkout@v2
          - uses: gryphonshafer/GitHub-MD-Book@v1
            with:
              settings: .github/github-md-book.yml

The `settings` value needs to point to a location within the repository that
contains a YAML file of settings. Without this, the build process will assume
defaults.

## Configuration Settings YAML File

The build configuration settings YAML file contains the setting for any number
of build runs. It can also contain a `defaults` section for default settings
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

### workspace

This is a directory that represents the top-level directory of a project
workspace, which will be searched in depth to find all files with the "md"
suffix. These files will be read in sort order to form the source markdown
content.

### filter

One or more sections (defined by header text) can be filtered using this option.
Filtered sections are removed throughout the source material, regardless of
their starting header level. The sections end upon the next header, regardless
of that header's level.

### append

One or more sections (defined by header text) can be copied and appended to the
end of the source material, much like an appendix.

### build_date

Date format to use to create a "build_date" environment variable for
substitutions. The default is: "%Y-%m-%d %H:%M:%S %Z"

### numerate

If this flag is set, headers (other than the cover page header) will be
numerated; meaning it will be given a number associated with its outline
location. For example, if a header is a level 2 header, it might render as:

    ## 3.7 Header

### cover

If this flag is set, the source content from the first header through to the
next header, regardless of header levels, will be considered content for a cover
page in all but the markdown outputs. It will be wrapped at the HTML stage in
a section tag with "cover" as ID:

    <section id="cover">...</section>

### toc

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

### remove_terms

If this flag is set, any terms/definitions found in the markdown source content
will be removed.

### glossary

If this flag is set, any terms/definitions found in the markdown source content
will be appended as a glossary.

### language

This is the language set in the HTML. The default is "en-us".

### encoding

This is the encoding set in the HTML and the encoding of the HTML output. The
default is "utf-8".

### directory

This option sets the output directory. If the directory does not exist, it will
be created. The default is "output".

### basename

This option sets the output basename. The default is "output", meaning that the
HTML output will be saved to "output.html" by default.

### types

One or more output types can be set using this option. If this option is not
specified, all outputs are set for types. The type options available are:
MD and HTML.

### insert

This option sets the file of assumed to be HTML header content to insert into
the header section of the HTML generated output. The default is: "header.html".

### style

This option sets the file of assumed to be CSS content to insert into the
header section of the HTML generated output. The default is: "style.css".

### paged

This option if set will result in an output file with name suffix ".paged.html"
to be generated. This file is intended to be viewed in a browser to preview
what a printed paged document should look like.

### quiet

This option if set will silence progress reports.

### env

Case-insensitive environment variable substitutions are supported and are
represented in the markdown source with a leading `$>.`For example:

    $example

This above will be replaced with any environment variable case-insensitively
matching "example".

## Publishing Output

This GitHub Action will build output, but then you'll need to do something with
that output. Below is an example of YAML you can tack on to the end of the
`~/.github/workflows/release.yml` example from above that will create a release
using the assets built into the "output" directory.

      - env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        shell: bash
        run: |-
          set -x
          assets=()
          for asset in ./output/*
          do
            assets+=("-a" "$asset")
          done
          now=$( date '+%Y-%m-%d %H:%M:%S %Z' )
          time=$( date '+%s' )
          branch=$( echo ${GITHUB_REF} | cut -c12-100 )
          [[ ${branch} == 'master' ]] && p="" || p="--prerelease"
          echo $GITHUB_TOKEN
          wget https://github.com/github/hub/releases/download/v2.14.2/hub-linux-amd64-2.14.2.tgz
          tar xvfpz hub-linux-amd64-2.14.2.tgz
          ./hub-linux-amd64-2.14.2/bin/hub release create "${assets[@]}" $p -m "$now - $branch" "$time"
