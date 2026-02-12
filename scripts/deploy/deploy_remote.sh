#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

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

get_root_env() {
  # Usage: get_root_env KEY DEFAULT
  local key="$1"
  local default="${2:-}"
  local line
  line="$(grep -E "^${key}=" .env | tail -n 1 || true)"
  if [[ -z "$line" ]]; then
    echo "$default"
    return 0
  fi
  echo "${line#*=}"
}

LLM_ENABLED="$(get_root_env LARAVEL_PALM_LLM_ENABLED false)"
LLM_MODEL="$(get_root_env LARAVEL_PALM_LLM_MODEL '')"
LLM_ENGLISH_MODEL="$(get_root_env LARAVEL_PALM_LLM_ENGLISH_MODEL '')"

# Ensure ollama is up before (optional) model pulls.
docker compose up -d ollama >/dev/null 2>&1 || true

if [[ "$LLM_ENABLED" == "true" ]]; then
  echo "LLM enabled; ensuring models are present in Ollama..."
  for model in "$LLM_MODEL" "$LLM_ENGLISH_MODEL"; do
    if [[ -z "$model" ]]; then
      continue
    fi

    if docker compose exec -T ollama ollama list | awk '{print $1}' | grep -qx "$model"; then
      echo "  model ok: $model"
    else
      echo "  pulling model: $model"
      docker compose exec -T ollama ollama pull "$model"
    fi
  done
fi

echo "Bringing services up..."
docker compose up -d --build laravel_app laravel_worker cv_service nginx

echo "Composer install..."
docker compose exec -T laravel_app composer install --no-interaction --prefer-dist --optimize-autoloader

echo "Laravel migrate..."
docker compose exec -T laravel_app php artisan migrate --force

echo "Laravel optimize:clear..."
docker compose exec -T laravel_app php artisan optimize:clear

echo "Health checks..."
curl -fsS http://localhost:8080/api/health >/dev/null
curl -fsS http://localhost:8001/health >/dev/null

echo "Deploy OK (UTC): $(date -u '+%Y-%m-%d %H:%M:%S')"

