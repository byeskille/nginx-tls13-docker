# To build and run this container locally, try a command like:
#
#        docker build -t nginx .
#        docker run --cap-drop=all --name nginx -d -p 80:8080 nginx
#

FROM ubuntu:16.04
MAINTAINER Øyvind Bye Skille <oyvind@byeskille.no>

# Nginx Version (See: https://nginx.org/en/CHANGES)
ENV NGXVERSION 1.13.0
ENV NGXSIGKEY B0F4253373F8F6F510D42178520A9993A1C052F8

# PageSpeed Version (See: https://modpagespeed.com/doc/release_notes)
ENV PSPDVER latest-beta

# OpenSSL Version (See: https://www.openssl.org/source/)
ENV OSSLVER 1.1.1-dev
ENV OSSLSIGKEY 0E604491

# Build as root (we drop privileges later when actually running the container)
USER root
WORKDIR /root

## not in

# Add 'nginx' user
RUN useradd nginx --system --uid 666  --home-dir /usr/share/nginx --no-create-home --shell /sbin/nologin

# Update
RUN apt-get update
RUN apt-get upgrade -y

#Install deps
RUN apt-get install -y \
        wget \
        git \
        gcc \
        make \
        libpcre3 \
        libpcre3-dev \
        zlib1g-dev &&\
    apt-get clean all

# Get sources into container
RUN wget https://nginx.org/download/nginx-$NGXVERSION.tar.gz
RUN git clone https://github.com/openssl/openssl && \
        cd openssl && \
        git checkout tls1.3-draft-18 && \
        cd ~

# Import nginx signing keys and verify the source code tarball
RUN gpg --keyserver keyserver.ubuntu.com --recv-keys $NGXSIGKEY && \
    wget "https://nginx.org/download/nginx-$NGXVERSION.tar.gz.asc" && \
    out=$(gpg --status-fd 1 --verify "nginx-$NGXVERSION.tar.gz.asc" 2>/dev/null) && \
    if echo "$out" | grep -qs "\[GNUPG:\] GOODSIG" && echo "$out" | grep -qs "\[GNUPG:\] VALIDSIG"; then echo "Good signature on nginx source."; else echo "GPG VERIFICATION OF NGINX SOURCE FAILED!" && echo "EXITING!" && exit 100; fi

# Extract nginx source
RUN tar -xzvf nginx-$NGXVERSION.tar.gz && \
    rm -v nginx-$NGXVERSION.tar.gz

# Not doing this part since I'm so fare pulling a branch from github for openssl with tls1.3 support
# Import OpenSSL signing keys and verify the source code tarball
#RUN gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys $OSSLSIGKEY && \
#    wget "https://www.openssl.org/source/openssl-$OSSLVER.tar.gz.asc" && \
#    out=$(gpg --status-fd 1 --verify "openssl-$OSSLVER.tar.gz.asc" 2>/dev/null) && \
#    if echo "$out" | grep -qs "\[GNUPG:\] GOODSIG" && echo "$out" | grep -qs "\[GNUPG:\] VALIDSIG"; then echo "Good signature on OpenSSL source."; else echo "GPG VERIFICATION OF OPENSSL SOURCE FAILED!" && echo "EXITING!" && exit 100; fi


# Switch directory
WORKDIR "/root/nginx-$NGXVERSION/"

# Configure Nginx
# Config options my already installed version of nginx on ubuntu 16.04 from nginx mainline repo.
# cc-opt tweaked to use -fstack-protector-all, and -fPIE added to build position-independent.
# The final tweaks are my --add-module lines at the bottom, and the --with-openssl
# argument, to point the build to the OpenSSL Beta we downloaded earlier.
RUN ./configure --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --http-client-body-temp-path=/var/cache/nginx/client_temp --http-proxy-temp-path=/var/cache/nginx/proxy_temp --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp --http-scgi-temp-path=/var/cache/nginx/scgi_temp --user=nginx --group=nginx --with-compat --with-file-aio --with-threads --with-http_addition_module --with-http_auth_request_module --with-http_dav_module --with-http_flv_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_mp4_module --with-http_random_index_module --with-http_realip_module --with-http_secure_link_module --with-http_slice_module --with-http_ssl_module --with-http_stub_status_module --with-http_sub_module --with-http_v2_module --with-mail --with-mail_ssl_module --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module --with-cc-opt='-g -O2 -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC' --with-ld-opt='-Wl,-Bsymbolic-functions -Wl,-z,relro -Wl,-z,now -Wl,--as-needed -pie' --with-openssl="$HOME/openssl"

# Build Nginx
RUN make && \
    make install

# Make sure the permissions are set correctly on our webroot, logdir and pidfile so that we can run the webserver as non-root.
RUN chown -R nginx:nginx /usr/share/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    mkdir -p /var/cache/nginx/ && \
    chown -R nginx:nginx /var/cache/nginx/ && \
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
