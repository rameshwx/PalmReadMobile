FROM php:8.3-fpm

RUN apt-get update && apt-get install -y \
    git unzip curl libpq-dev libzip-dev libpng-dev libonig-dev \
    libjpeg-dev libfreetype6-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install gd pdo pdo_pgsql pgsql zip \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

COPY . /var/www/html
COPY docker/php/entrypoint.sh /usr/local/bin/palmread-php-entrypoint

RUN composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader --no-scripts \
    && mkdir -p storage/framework/cache storage/framework/sessions storage/framework/views storage/logs bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod +x /usr/local/bin/palmread-php-entrypoint

ENTRYPOINT ["/usr/local/bin/palmread-php-entrypoint"]
CMD ["php-fpm"]
