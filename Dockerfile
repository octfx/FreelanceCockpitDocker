### Extensions
FROM php:7.3-apache as extensions

LABEL stage=intermediate

RUN set -ex; \
    \
    savedAptMark="$(apt-mark showmanual)"; \
    \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        libcurl4-gnutls-dev \
#        libbz2-dev \
#        libc-client-dev \
#        libkrb5-dev \
        libpng-dev \
        libxml2-dev \
        libzip-dev \
    ; \
    \
#    docker-php-ext-configure imap --with-kerberos --with-imap-ssl; \
    docker-php-ext-install \
        curl \
        dom \
#        imap \
        gd \
        json \
        mbstring \
        mysqli \
        opcache \
        pdo_mysql \        
        zip \
    ; \
    \
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $savedAptMark; \
    ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
        | awk '/=>/ { print $3 }' \
        | sort -u \
        | xargs -r dpkg-query -S \
        | cut -d: -f1 \
        | sort -u \
        | xargs -rt apt-mark manual; \
    \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*

RUN echo '\
opcache.enable=1\n\
opcache.memory_consumption=256\n\
opcache.interned_strings_buffer=16\n\
opcache.max_accelerated_files=16000\n\
opcache.validate_timestamps=0\n\
opcache.load_comments=Off\n\
opcache.save_comments=1\n\
opcache.fast_shutdown=0\n\
' >> /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini && \
    echo 'memory_limit = 128M' >> /usr/local/etc/php/conf.d/docker-php-memlimit.ini && \
    echo 'max_execution_time = 60' >> /usr/local/etc/php/conf.d/docker-php-executiontime.ini

### Final
FROM php:7.3-apache

COPY --from=extensions /usr/local/etc/php/conf.d/*.ini /usr/local/etc/php/conf.d/
COPY --from=extensions /usr/local/lib/php/extensions/no-debug-non-zts-20180731/*.so /usr/local/lib/php/extensions/no-debug-non-zts-20180731/
COPY --from=extensions /usr/lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu

RUN chown -R www-data:www-data /var/www/html && \
    a2enmod rewrite
