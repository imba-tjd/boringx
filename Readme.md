# BoringSSL NGINX -- BoringX

[![docker build](https://img.shields.io/docker/cloud/build/imbatjd/boringx.svg)](https://hub.docker.com/r/imbatjd/boringx/builds/) [![GitHub Actions](https://github.com/imba-tjd/boringx/workflows/Build/badge.svg)](https://github.com/imba-tjd/boringx/actions) [![Image size](https://images.microbadger.com/badges/image/imbatjd/boringx:slim.svg)](https://microbadger.com/images/imbatjd/boringx)

Cutting-edge NGINX built with BoringSSL, Clang 11 and Docker, supporting [`CECPQ2`](mainline/alpine/nginx.conf#L34) post-quantum key exchange algorithm.

Since the CECPQ2 testing seems end, I'm not going to build nginx with boringssl any more.

## Get

There are three **diffrerent** release you can choose. You can also easily build your own, of course.

1. `docker pull imbatjd/boringx`, which is the most full-featured one, though basically the same as `nginx-modules/docker-nginx-boringssl`.
2. `docker pull imbatjd/boringx:slim`, which contains some basic features.
3. The binary in Actions, which contains the least features and is usable only for debian (series).

Note: I'm still in the process of learning NGINX so this project might not work and be unstable. For example I have never used GeoIP2.

### Help wanted

* nginx: [warn] "ssl_stapling" ignored, not supported
* nginx: [emerg] SSL_CTX_set_cipher_list("TLS_AES_128_GCM_SHA256") failed (SSL: error:100000b1:SSL routines:OPENSSL_internal:NO_CIPHER_MATCH)
* When I used `ln gcc-10 cc`, etc., it weirdly caused BoringSSL and Nginx to fail to detect the correct gcc version in GitHub Actions, but it works in my docker golang sandbox. See [build.yml#L39](.github/workflows/build.yml#L39).
* the `rm -rf "$GNUPGHOME" nginx.tar.gz.asc` sometimes fails and prints `No such file or directory`. Shouldn't the `-f` make it success even if the file doesn't exist? I tried this command multiple times with no error.

## TODO

* 有人表示envsubst需要libintl才能工作
* depth取2，如果Dockerfile没变化就不构建

## 其它笔记

* `elgohr/Publish-Docker-Github-Action`：这个actions把build和push弄到一起了，我只想push，build命令我自己写
* `envsubst`在`gettext`中
* `zlib`用于支持gzip
* `libbrotli`已经不再需要单独安装
* 保存并压缩映像：`docker save imbatjd/boringx:master | xz -9e > boringx.xz;`；载入压缩过的映像：`unzip -p boringx.xz.zip | xz -dc | docker load`；不知`load -i`能否自动识别`.xz.zip`？
* 静态连接boringssl（--with-openssl）必须要`touch /usr/src/boringssl/include/openssl/ssl.h`，且必须在NGINX的configure之后做，否则会报`./config: not found...Error 127`。然而该文件确实是存在的，在configure后也存在；如果自己加cc-opt和ld-opt就没问题。迷
* apt的source不能全部替换成testing，否则会报debian-security testing/updates Release does not have a Release file.
* 直接在Acions里用clang+boringssl构建能成功，但是-V时Segmentation Fault
* Google Cloud Shell只要安装upx（和clang）就好了

## Based on

* https://github.com/nginx-modules/docker-nginx-boringssl
* https://github.com/bpowers/docker-nginx-boringssl
* https://github.com/nginxinc/docker-nginx/blob/master/mainline/alpine/Dockerfile 官方dockerfile
* https://github.com/alexhaydock/BoringNginx
* https://github.com/RanadeepPolavarapu/docker-nginx-http3
* https://github.com/nginx/nginx/blob/master/auto/options 官方makefile选项，其中以--without开头的都是可取消的默认构建模块
* https://docshome.gitbooks.io/nginx-docs/How-To/从源码构建nginx.html 编译参数和预编译模块的解释
* https://stackoverflow.com/questions/54750830/autotools-configure-error-when-passing-options-using-shell-variable
