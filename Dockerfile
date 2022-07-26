FROM debian:latest

COPY ./ /github-md-book/

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y build-essential wget perl libperl-dev libpng-dev cpanminus chromium nodejs npm && \
    npm install -g chrome-headless-render-pdf node-static && \
    cd /github-md-book && \
    cpanm -n -f --installdeps . && \
    rm -rf ~/.cpanm

ENTRYPOINT ["/github-md-book/build.pl"]
