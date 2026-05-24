# Используем официальный образ nginx с поддержкой brotli сжатия
FROM nginx:alpine

# Устанавливаем необходимые пакеты для brotli
RUN apk add --no-cache --virtual .build-deps \
    git \
    gcc \
    libc-dev \
    make \
    automake \
    autoconf \
    libtool \
    pkgconfig \
    && git clone https://github.com/google/ngx_brotli.git /tmp/ngx_brotli \
    && cd /tmp/ngx_brotli && git submodule update --init \
    && cd /usr/src/nginx \
    && apk add --no-cache --virtual .build-deps \
        linux-headers \
        openssl-dev \
        pcre-dev \
        zlib-dev \
    && wget https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz \
    && tar -xzf nginx-${NGINX_VERSION}.tar.gz \
    && cd nginx-${NGINX_VERSION} \
    && ./configure --with-compat --add-dynamic-module=/tmp/ngx_brotli \
    && make modules \
    && cp objs/ngx_http_brotli_filter_module.so /etc/nginx/modules/ \
    && cp objs/ngx_http_brotli_static_module.so /etc/nginx/modules/ \
    && rm -rf /tmp/ngx_brotli /usr/src/nginx

# Загружаем модуль brotli
RUN echo "load_module /etc/nginx/modules/ngx_http_brotli_filter_module.so;" > /etc/nginx/conf.d/brotli.conf && \
    echo "load_module /etc/nginx/modules/ngx_http_brotli_static_module.so;" >> /etc/nginx/conf.d/brotli.conf

# Копируем файлы сайта
COPY . /usr/share/nginx/html

# Копируем кастомную конфигурацию nginx
COPY nginx.conf /etc/nginx/nginx.conf

# Создаем скрипт для обработки SPA роутинга (для 404 страницы)
RUN echo '#!/bin/sh\n\
sed -i "s/error_page 404 \/404.html;/error_page 404 =200 \/index.html;/g" /etc/nginx/conf.d/default.conf\n\
nginx -g "daemon off;"' > /docker-entrypoint.sh && chmod +x /docker-entrypoint.sh

# Открываем порт 80
EXPOSE 80

# Запускаем nginx с нашей конфигурацией
CMD ["/docker-entrypoint.sh"]