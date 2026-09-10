FROM ghcr.io/cirruslabs/flutter:stable AS flutter_web_build

WORKDIR /workspace/flutter_app

COPY flutter_app/pubspec.yaml flutter_app/pubspec.lock ./
RUN flutter pub get

COPY flutter_app/ ./

ARG API_BASE_URL=http://localhost:8080
ARG API_BASE_PATH=/palmread
RUN flutter build web --release \
    --dart-define=API_BASE_URL="${API_BASE_URL}" \
    --dart-define=API_BASE_PATH="${API_BASE_PATH}"

FROM nginx:1.27-alpine

COPY laravel_api/docker/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY laravel_api/public /var/www/html/public
COPY --from=flutter_web_build /workspace/flutter_app/build/web /var/www/html/web
