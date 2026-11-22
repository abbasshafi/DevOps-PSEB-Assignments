# Stage 1: PHP dependencies
FROM composer:2 AS vendor
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist --ignore-platform-reqs
COPY . .
RUN composer dump-autoload --optimize --no-dev

# Stage 2: frontend assets (a fresh Laravel page fails without public/build)
FROM node:20-alpine AS assets
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 3: final image (nginx + php-fpm already bundled, listens on 8080)
FROM serversideup/php:8.3-fpm-nginx
WORKDIR /var/www/html
COPY --chown=www-data:www-data --from=vendor /app ./
COPY --chown=www-data:www-data --from=assets /app/public/build ./public/build
