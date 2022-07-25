FROM debian:latest

COPY ./ /github-md-book/

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y build-essential wget perl libperl-dev cpanminus && \
    cd /github-md-book && \
    cpanm -n -f --installdeps . && \
    rm -rf /master.tar.gz /fonts-main /var/cache/* ~/.cpanm

ENTRYPOINT ["/github-md-book/build.pl"]
