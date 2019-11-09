## nginx-tls13-docker

**deprecated:** This repo is not updated at all anymore. Ubuntu 18.04 with nginx from the official repos now support TLS 1.3 out of the box. And that is more recommended even for experimentation.

A simple Docker container compiling [Nginx](http://nginx.org/en/download.html) from source together with [Openssl](https://github.com/openssl/openssl/tree/tls1.3-draft-18) from the the latest code on Github and the branch supporting TLS 1.3 draft 18.

Size of built image: 225 MB

### Usage

This project is under [WTFPL](LICENSE.md). So you can pretty much do whatever you want with it.

Do be warned this has had not been tested for production, and the [Dockerfile](Dockerfile) is written by a person with very little knowledge about all this stuff.
