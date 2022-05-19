FROM debian:latest

COPY ./ /github-md-book/

RUN apt update && \
    apt upgrade -y && \
    apt install -y build-essential wget perl libperl-dev cpanminus yarnpkg chromium && \
    yarnpkg global add pagedjs-cli@latest && \
    wget -q https://github.com/google/fonts/archive/master.tar.gz && \
    tar xfpz master.tar.gz && \
    mkdir -p /usr/share/fonts/truetype/google-fonts && \
    find fonts-main -name "*.ttf" \
        -exec install -m644 {} /usr/share/fonts/truetype/google-fonts/ \; || echo "ERROR" && \
    fc-cache -f && \
    cd /github-md-book && \
    cpanm -n -f --installdeps . && \
    rm -rf /master.tar.gz /fonts-main /var/cache/* ~/.cpanm

ENTRYPOINT ["/github-md-book/build.pl"]
