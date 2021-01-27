# syntax = docker/dockerfile:experimental
FROM alpine:edge AS builder

ENV NGINX_VERSION=1.19.3
ARG BUILD_GEOIP2=false

RUN GPG_KEYS=B0F4253373F8F6F510D42178520A9993A1C052F8 \
	&& CONFIG="\
		--prefix=/etc/nginx \
		--sbin-path=/usr/sbin/nginx \
		--modules-path=/usr/lib/nginx/modules \
		--conf-path=/etc/nginx/nginx.conf \
		--error-log-path=/var/log/nginx/error.log \
		--http-log-path=/var/log/nginx/access.log \
		--pid-path=/var/run/nginx.pid \
		--lock-path=/var/run/nginx.lock \
		--http-client-body-temp-path=/var/cache/nginx/client_temp \
		--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
		--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
		--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
		--user=nginx \
		--group=nginx \
		--with-pcre-jit \
		--with-http_ssl_module \
		--with-http_realip_module \
		--with-http_addition_module \
		--with-http_sub_module \
		--with-http_secure_link_module \
		--with-threads \
		--with-stream=dynamic \
		--with-stream_ssl_module \
		--with-stream_ssl_preread_module \
		--with-stream_realip_module \
		--with-http_slice_module \
		--with-file-aio \
		--with-http_v2_module \
		--with-openssl=/usr/src/boringssl \
		--add-module=/usr/src/ngx_brotli \
		--without-select_module \
		--without-poll_module \
		--without-http_gzip_module \
		--without-http_ssi_module \
		--without-http_userid_module \
		--without-http_mirror_module \
		--without-http_split_clients_module \
		--without-http_referer_module \
		--without-http_scgi_module \
		--without-http_memcached_module \
		--without-http_empty_gif_module \
		--without-http_browser_module \
		--without-http_upstream_random_module \
		--without-mail_pop3_module \
		--without-mail_imap_module \
		--without-mail_smtp_module \
		--without-stream_split_clients_module \
		--without-stream_upstream_random_module \
	" \
	&& CMPL_FLAGS="-O2 -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2" \
	&& CC_OPTS=--with-cc-opt="$CMPL_FLAGS" \
	&& LD_OPTS=--with-ld-opt="-Wl,-z,relro -Wl,-z,now -Wl,--as-needed" \
	&& addgroup -S nginx \
	&& adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
	&& apk add --no-cache \
		binutils \
		build-base \
		cmake \
		curl \
		gcc \
		g++ \
		gd-dev \
		gettext \
		git \
		gnupg \
		go \
		libc-dev \
		libgcc \
		libstdc++ \
		linux-headers \
		make \
		pcre-dev \
		tar \
	&& [ $BUILD_GEOIP2 = "false" ] || ( \
		CONFIG="$CONFIG --add-dynamic-module=/usr/src/ngx_http_geoip2_module" && \
		apk add --no-cache gzip libmaxminddb-dev && \
		git clone --depth 1 https://github.com/leev/ngx_http_geoip2_module.git /usr/src/ngx_http_geoip2_module && \
		curl -L "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country&license_key=$GEOIP2_LICENSE_KEY&suffix=tar.gz" -o GeoLite2-Country.mmdb.gz && \
		gunzip GeoLite2-Country.mmdb.gz && \
		mkdir -p /etc/nginx/GeoIP2 && \
		cp ./GeoLite2-Country.mmdb /etc/nginx/GeoIP2/) \
	&& curl -L https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz \
	&& curl -L https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz.asc  -o nginx.tar.gz.asc \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& server='hkp://keyserver.ubuntu.com:80' \
	&& gpg --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$GPG_KEYS" \
	&& gpg --batch --verify nginx.tar.gz.asc nginx.tar.gz \
	&& rm -rf "$GNUPGHOME" nginx.tar.gz.asc \
	&& mkdir -p /usr/src \
	\
	&& git clone --depth=1 --recurse-submodules --shallow-submodules https://github.com/google/ngx_brotli /usr/src/ngx_brotli \
	&& (git clone --depth=1 https://boringssl.googlesource.com/boringssl /usr/src/boringssl \
		&& sed -i 's@out \([>=]\) TLS1_2_VERSION@out \1 TLS1_3_VERSION@' /usr/src/boringssl/ssl/ssl_lib.cc \
		&& sed -i 's@ssl->version[ ]*=[ ]*TLS1_2_VERSION@ssl->version = TLS1_3_VERSION@' /usr/src/boringssl/ssl/s3_lib.cc \
		&& sed -i 's@(SSL3_VERSION, TLS1_2_VERSION@(SSL3_VERSION, TLS1_3_VERSION@' /usr/src/boringssl/ssl/ssl_test.cc \
		&& sed -i 's@\$shaext[ ]*=[ ]*0;@\$shaext = 1;@' /usr/src/boringssl/crypto/*/asm/*.pl \
		&& sed -i 's@\$avx[ ]*=[ ]*[0|1];@\$avx = 2;@' /usr/src/boringssl/crypto/*/asm/*.pl \
		&& sed -i 's@\$addx[ ]*=[ ]*0;@\$addx = 1;@' /usr/src/boringssl/crypto/*/asm/*.pl \
		&& mkdir -p /usr/src/boringssl/build /usr/src/boringssl/.openssl/lib /usr/src/boringssl/.openssl/include \
		&& ln -sf /usr/src/boringssl/include/openssl /usr/src/boringssl/.openssl/include/openssl \
		&& CPPFLAGS='-D_FORTIFY_SOURCE=2' CFLAGS=$CMPL_FLAGS CXXFLAGS=$CMPL_FLAGS cmake -B/usr/src/boringssl/build -H/usr/src/boringssl -DCMAKE_BUILD_TYPE=Release \
		&& make ssl VERBOSE=1 -C/usr/src/boringssl/build -j$(getconf _NPROCESSORS_ONLN) \
		&& cp /usr/src/boringssl/build/crypto/libcrypto.a /usr/src/boringssl/build/ssl/libssl.a /usr/src/boringssl/.openssl/lib) \
	\
	&& tar -zxC /usr/src -f nginx.tar.gz \
	&& rm nginx.tar.gz \
	&& cd /usr/src/nginx-$NGINX_VERSION \
	&& curl -fSL https://raw.githubusercontent.com/nginx-modules/ngx_http_tls_dyn_size/0.5/nginx__dynamic_tls_records_1.17.7%2B.patch -o dynamic_tls_records.patch \
	&& patch -p1 < dynamic_tls_records.patch \
	&& ./configure $CONFIG "$CC_OPTS" "$LD_OPTS" \
	&& touch /usr/src/boringssl/include/openssl/ssl.h \
	&& make -j$(getconf _NPROCESSORS_ONLN) \
	&& make install \
	&& rm -rf /etc/nginx/html/ \
	&& mkdir /etc/nginx/conf.d/ \
	&& mkdir -p /usr/share/nginx/html/ \
	&& install -m644 html/index.html /usr/share/nginx/html/ \
	&& install -m644 html/50x.html /usr/share/nginx/html/ \
	&& ln -s ../../usr/lib/nginx/modules /etc/nginx/modules \
	&& strip /usr/sbin/nginx* \
	&& strip /usr/lib/nginx/modules/*.so \
	&& rm -rf /usr/src/nginx-$NGINX_VERSION \
	&& rm -rf /usr/src/boringssl /usr/src/ngx_* \
	\
	# 要在运行时中安装的依赖
	&& runDeps="$( \
		scanelf --needed --nobanner /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
			| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			| sort -u \
			| xargs -r apk info --installed \
			| sort -u \
	)" \
	&& echo $runDeps > /rundeps.txt \
	\
	# forward request and error logs to docker log collector
	&& ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log \
	;

# 在builder中添加，之后复制到运行时容器，减少层数
COPY nginx.conf /etc/nginx/nginx.conf
COPY nginx.vh.no-default.conf /etc/nginx/conf.d/default.conf

# 用于防止server_name不匹配的自签证书
RUN apk add --no-cache openssl && \
	mkdir -p /etc/nginx/certs && \
	cd /etc/nginx/certs && \
	openssl req -newkey ed25519 -keyout localhost.key -sha512-256 -x509 -nodes -days 365 -out localhost.crt -subj "/CN=localhost";

FROM alpine

RUN --mount=type=bind,from=builder,source=/,target=/artifacts \
	apk add --no-cache $(cat /artifacts/rundeps.txt) \
	# diffutils tini \
	ca-certificates tzdata && \
	addgroup -S nginx && \
	adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx && \
	cp -a /artifacts/etc/nginx /etc/ && \
	cp -a /artifacts/usr/lib/nginx /usr/lib/ && \
	cp -a /artifacts/usr/share/nginx /usr/share/ && \
	cp -a /artifacts/var/cache/nginx /var/cache/ && \
	cp -a /artifacts/var/log/nginx /var/log/ && \
	cp -p /artifacts/usr/sbin/nginx /usr/sbin/ && \
	cp -p /artifacts/usr/bin/envsubst /usr/local/bin/ && \
	chown nginx: /var/log/nginx/access.log /var/log/nginx/error.log && \
	echo "" && nginx -V;

CMD ["nginx", "-g", "daemon off;"]
