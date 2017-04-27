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
ENV OSSLVER 1.1.0e
ENV OSSLSIGKEY 0E604491

# Build as root (we drop privileges later when actually running the container)
USER root
WORKDIR /root
