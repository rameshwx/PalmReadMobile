#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"
COMPOSE_FILES=(-f docker-compose.yml -f docker-compose.local.yml)

if [[ ! -f docker-compose.yml ]]; then
  echo "ERROR: docker-compose.yml not found in $ROOT_DIR" >&2
  exit 1
fi

if [[ ! -f .env ]]; then
  echo "ERROR: $ROOT_DIR/.env is missing. Create it from .env.example on the server." >&2
  exit 1
fi

echo "Deploy start (UTC): $(date -u '+%Y-%m-%d %H:%M:%S')"
echo "Deploy root: $ROOT_DIR"

echo "Bringing services up..."
docker compose "${COMPOSE_FILES[@]}" up -d --build laravel_app laravel_worker cv_service nginx

echo "Composer install..."
docker compose "${COMPOSE_FILES[@]}" exec -T laravel_app composer install --no-interaction --prefer-dist --optimize-autoloader

echo "Laravel migrate..."
docker compose "${COMPOSE_FILES[@]}" exec -T laravel_app php artisan migrate --force

echo "Laravel optimize:clear..."
docker compose "${COMPOSE_FILES[@]}" exec -T laravel_app php artisan optimize:clear

echo "Health checks..."
curl -fsS http://localhost:8080/palmread/api/health >/dev/null
curl -fsS http://localhost:8001/health >/dev/null

echo "Deploy OK (UTC): $(date -u '+%Y-%m-%d %H:%M:%S')"
