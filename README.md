## nginx-tls13-docker

A simple Docker container compiling [Nginx](http://nginx.org/en/download.html) from source together with [Openssl](https://github.com/openssl/openssl/) from the the latest code on Github and the branch supporting TLS 1.3 draft 18.

The `openssl-master` branch compiles with the master branch from openssl. The `dev` branch compiles with the tls1.3-draft-18 branch of openssl.

Size of built image: ca 210 MB

Can also be found on as pre-built image on Docker Hub as: [byeskille/nginx-tls13-docker](https://hub.docker.com/r/byeskille/nginx-tls13-docker/)

### Usage

This project is under [WTFPL](LICENSE.md). So you can pretty much do whatever you want with it.

Do be warned this has had not been tested for production, and the [Dockerfile](Dockerfile) is written by a person with very little knowledge about all this stuff.
