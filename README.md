# PalmReadMobile v1

Production-oriented monorepo for palm reading with deterministic CPU CV, Laravel API, and Flutter mobile app.

## Components
- `flutter_app/`: Flutter Android/iOS app (Riverpod + Dio).
- `laravel_api/`: Laravel REST API with Sanctum + Redis queue.
- `cv_service/`: FastAPI + OpenCV CPU-only CV service.

## Quick Start (Docker Compose)
1. Copy env template:
   ```bash
   cp .env.example .env
   ```
2. Build and start services:
   ```bash
   docker compose up --build -d
   ```
3. Initialize Laravel app (inside container):
   ```bash
   docker compose exec laravel_app composer install
   docker compose exec laravel_app cp .env.example .env
   docker compose exec laravel_app php artisan key:generate
   docker compose exec laravel_app php artisan migrate
   ```
4. CV service health:
   ```bash
   curl http://localhost:8001/health
   ```
5. API health:
   ```bash
   curl http://localhost:8080/api/health
   ```
6. (Optional) Enable local LLM reading generation:
   ```bash
   # In .env set:
   # LARAVEL_PALM_LLM_ENABLED=true
   # LARAVEL_PALM_LLM_MODEL=llama3.2:1b
   # LARAVEL_PALM_LLM_FORCE_ENGLISH=true
   # LARAVEL_PALM_LLM_ENGLISH_MODEL=llama3.2:1b
   docker compose up -d ollama
   docker compose exec -T ollama ollama pull llama3.2:1b
   docker compose up -d --force-recreate laravel_app laravel_worker
   ```

## Non-Docker VM Deploy
See:
- `laravel_api/README.md`
- `cv_service/README.md`
- `flutter_app/README.md`

## Acceptance Smoke Flow
1. Register user with `/api/auth/register`.
2. Login `/api/auth/login` and use bearer token.
3. Upload image via `POST /api/palm-reads`.
4. Poll `GET /api/palm-reads/{id}` until `completed`.
5. Fetch overlay from `/api/palm-reads/{id}/overlay`.
6. Submit feedback via `/api/palm-reads/{id}/feedback`.
