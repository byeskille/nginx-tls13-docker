# To build and run this container locally, try a command like:
#
#        docker build -t nginx .
#        docker run --cap-drop=all --name nginx -d -p 80:8080 nginx
#

FROM debian:latest
MAINTAINER Øyvind Bye Skille <oyvind@byeskille.no>

# Nginx Version (See: https://nginx.org/en/CHANGES)
ENV NGXVERSION 1.13.0
ENV NGXSIGKEY B0F4253373F8F6F510D42178520A9993A1C052F8

# PageSpeed Version (See: https://modpagespeed.com/doc/release_notes)
ENV PSPDVER latest-beta

# OpenSSL Version (See: https://www.openssl.org/source/)
ENV OSSLVER 1.1.0e
ENV OSSLSIGKEY 0E604491

# Build as root (we drop privileges later when actually running the container)
USER root
WORKDIR /root

# Add 'nginx' user
RUN useradd nginx --system --uid 666  --home-dir /usr/share/nginx --no-create-home --shell /sbin/nologin

# Update & install deps
RUN yum install -y \
        gcc \
        gcc-c++ \
        GeoIP-devel \
        git \
        gperftools-devel \
        make \
        pcre-devel \
        tar \
        unzip \
        wget \
        zlib-devel && \
    yum clean all

# Copy sources into container
COPY src/nginx-$NGXVERSION.tar.gz nginx-$NGXVERSION.tar.gz
COPY src/openssl-$OSSLVER.tar.gz openssl-$OSSLVER.tar.gz

# Import nginx signing keys and verify the source code tarball
RUN gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys $NGXSIGKEY && \
    wget "https://nginx.org/download/nginx-$NGXVERSION.tar.gz.asc" && \
    out=$(gpg --status-fd 1 --verify "nginx-$NGXVERSION.tar.gz.asc" 2>/dev/null) && \
    if echo "$out" | grep -qs "\[GNUPG:\] GOODSIG" && echo "$out" | grep -qs "\[GNUPG:\] VALIDSIG"; then echo "Good signature on nginx source."; else echo "GPG VERIFICATION OF NGINX SOURCE FAILED!" && echo "EXITING!" && exit 100; fi

# Extract nginx source
RUN tar -xzvf nginx-$NGXVERSION.tar.gz && \
    rm -v nginx-$NGXVERSION.tar.gz

# Import OpenSSL signing keys and verify the source code tarball
RUN gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys $OSSLSIGKEY && \
    wget "https://www.openssl.org/source/openssl-$OSSLVER.tar.gz.asc" && \
    out=$(gpg --status-fd 1 --verify "openssl-$OSSLVER.tar.gz.asc" 2>/dev/null) && \
    if echo "$out" | grep -qs "\[GNUPG:\] GOODSIG" && echo "$out" | grep -qs "\[GNUPG:\] VALIDSIG"; then echo "Good signature on OpenSSL source."; else echo "GPG VERIFICATION OF OPENSSL SOURCE FAILED!" && echo "EXITING!" && exit 100; fi

# Extract OpenSSL source
RUN tar -xzvf openssl-$OSSLVER.tar.gz && \
    rm -v openssl-$OSSLVER.tar.gz

# Download PageSpeed
RUN wget https://github.com/pagespeed/ngx_pagespeed/archive/$PSPDVER.tar.gz && \
    tar -xzvf $PSPDVER.tar.gz && \
    rm -v $PSPDVER.tar.gz && \
    cd ngx_pagespeed-$PSPDVER/ && \
    echo "Downloading PSOL binary from the URL specified in the PSOL_BINARY_URL file..." && \
    PSOLURL=$(cat PSOL_BINARY_URL | grep https: | sed 's/$BIT_SIZE_NAME/x64/g') && \
    wget $PSOLURL && \
    tar -xzvf *.tar.gz && \
    rm -v *.tar.gz

# Download additional modules
RUN git clone https://github.com/openresty/headers-more-nginx-module.git "$HOME/ngx_headers_more" && \
    git clone https://github.com/simpl/ngx_devel_kit.git "$HOME/ngx_devel_kit" && \
    git clone https://github.com/yaoweibin/ngx_http_substitutions_filter_module.git "$HOME/ngx_subs_filter"

# Switch directory
WORKDIR "/root/nginx-$NGXVERSION/"

# Configure Nginx
# Config options stolen from the current packaged version of nginx for Fedora 25.
# cc-opt tweaked to use -fstack-protector-all, and -fPIE added to build position-independent.
# Removed any of the modules that the Fedora team was building with "=dynamic" as they stop us being able
# to build with -fPIE and require the less-hardened -fPIC option instead. (https://gcc.gnu.org/onlinedocs/gcc/Code-Gen-Options.html)
# Also removed the --with-debug flag (I don't need debug-level logging) and --with-ipv6 as the flag is now deprecated.
# Removed all the mail modules as I have no intention of using this as a mailserver proxy.
# The final tweaks are my --add-module lines at the bottom, and the --with-openssl
# argument, to point the build to the OpenSSL Beta we downloaded earlier.
RUN ./configure \
        --prefix=/usr/share/nginx \
        --sbin-path=/usr/sbin/nginx \
        --modules-path=/usr/lib64/nginx/modules \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --http-client-body-temp-path=/var/lib/nginx/tmp/client_body \
        --http-proxy-temp-path=/var/lib/nginx/tmp/proxy \
        --http-fastcgi-temp-path=/var/lib/nginx/tmp/fastcgi \
        --http-uwsgi-temp-path=/var/lib/nginx/tmp/uwsgi \
        --http-scgi-temp-path=/var/lib/nginx/tmp/scgi \
        --pid-path=/run/nginx.pid \
        --lock-path=/run/lock/subsys/nginx \
        --user=nginx \
        --group=nginx \
        --with-file-aio \
        --with-http_ssl_module \
        --with-http_v2_module \
        --with-http_realip_module \
        --with-http_addition_module \
        --with-http_sub_module \
        --with-http_dav_module \
        --with-http_flv_module \
        --with-http_mp4_module \
        --with-http_geoip_module \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_random_index_module \
        --with-http_secure_link_module \
        --with-http_degradation_module \
        --with-http_slice_module \
        --with-http_stub_status_module \
        --with-pcre \
        --with-pcre-jit \
        --with-stream \
        --with-stream_ssl_module \
        --with-google_perftools_module \
        --with-cc-opt='-fPIE -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-all' \
        --with-ld-opt='-Wl,-z,relro' \
        --with-openssl="$HOME/openssl-$OSSLVER" \
        --add-module="$HOME/ngx_pagespeed-$PSPDVER" \
        --add-module="$HOME/ngx_headers_more" \
        --add-module="$HOME/ngx_devel_kit" \
        --add-module="$HOME/ngx_subs_filter"

# Build Nginx
RUN make && \
    make install

# Make sure the permissions are set correctly on our webroot, logdir and pidfile so that we can run the webserver as non-root.
RUN chown -R nginx:nginx /usr/share/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    mkdir -p /var/lib/nginx/tmp && \
    chown -R nginx:nginx /var/lib/nginx && \
    touch /run/nginx.pid && \
    chown -R nginx:nginx /run/nginx.pid

# Configure nginx to listen on 8080 instead of 80 (we can't bind to <1024 as non-root)
RUN perl -pi -e 's,80;,8080;,' /etc/nginx/nginx.conf

# Print built version
RUN nginx -V

# Launch Nginx in container as non-root
USER nginx
WORKDIR /usr/share/nginx

# Launch command
CMD ["nginx", "-g", "daemon off;"]
