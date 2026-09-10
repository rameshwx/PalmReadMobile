# Laravel API (`laravel_api`)

REST API for palm reads with Sanctum auth, queue processing, CV integration, deterministic reading, and feedback collection.

## Features
- Sanctum email/password auth.
- `POST /api/palm-reads` queues analysis jobs.
- Redis queue worker processes CV results.
- Deterministic reading generator from quantized features.
- Deduplication by `hand_signature_hash` with overlay recomputed per upload.
- Retention policy for image cleanup.

## Routes
- `POST /api/auth/register`
- `POST /api/auth/login`
- `POST /api/palm-reads`
- `GET /api/palm-reads`
- `GET /api/palm-reads/{id}`
- `GET /api/palm-reads/{id}/overlay`
- `POST /api/palm-reads/{id}/feedback`

## Environment Variables
- `APP_ENV`, `APP_KEY`, `APP_URL`
- `DB_CONNECTION`, `DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`
- `QUEUE_CONNECTION=redis`
- `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`, `REDIS_CLIENT`
- `CACHE_STORE=file`, `SESSION_DRIVER=file`
- `SANCTUM_STATEFUL_DOMAINS`
- `CV_SERVICE_BASE_URL`
- `PALM_STORAGE_DISK=palms`
- `PALM_IMAGE_RETENTION_DAYS=30`
- `PALM_UPLOAD_MAX_MB=8`
- `PALM_POLLING_RECOMMENDED_SECONDS=2`
- `PALM_HISTORY_LIMIT=10`
- `PALM_LLM_ENABLED=false`
- `PALM_OPENROUTER_API_KEY=` (keep this outside Git)
- `PALM_OPENROUTER_BASE_URL=https://openrouter.ai/api/v1`
- `PALM_OPENROUTER_MODEL=openai/gpt-4o`
- `PALM_LLM_TIMEOUT_SECONDS=60`
- `PALM_LLM_TEMPERATURE=0`
- `PALM_LLM_NUM_PREDICT=900` (the single combined reading response needs room for all fields)
- `PALM_LLM_SEED=42`
- `PALM_LLM_FORCE_ENGLISH=true`
- `PALM_LLM_REQUIRE_SUCCESS=false`

## Local Dev (without Docker)
1. Install PHP 8.3+, Composer 2, Redis, SQLite or PostgreSQL.
2. Create app (if you want a fully bootable framework skeleton):
   ```bash
   composer create-project laravel/laravel laravel_api
   ```
3. Copy these app/config/routes/tests files into the generated project.
4. Install Sanctum:
   ```bash
   composer require laravel/sanctum
   php artisan vendor:publish --provider="Laravel\\Sanctum\\SanctumServiceProvider"
   php artisan migrate
   ```
5. Run:
   ```bash
   php artisan serve --host=0.0.0.0 --port=8080
   php artisan queue:work redis --queue=palm_reads
   php artisan schedule:work
   ```

## Production VM (non-Docker)
1. Ubuntu 22.04, install Nginx, PHP-FPM 8.3, Composer, Redis, PostgreSQL.
2. Deploy code to `/var/www/laravel_api`.
3. Configure Nginx root to `/var/www/laravel_api/public`.
4. Run worker + scheduler via Supervisor.
5. Keep `storage/app/palms` writable by PHP user and not web-exposed.

## Horizon (optional)
Enable by installing `laravel/horizon` and running `php artisan horizon` instead of `queue:work`.

## Optional OpenRouter Humanization
1. Set `PALM_OPENROUTER_API_KEY` in the Laravel server environment. Do not commit it or place it in the Flutter app.
2. Set `PALM_LLM_ENABLED=true` and recreate the Laravel app/worker.
3. Each palm read makes one combined OpenRouter request for the narrative, disclaimer, and five line insights. Reading generation will fallback to deterministic templates if OpenRouter is unavailable or returns invalid output.

## English-Only Enforcement
When `PALM_LLM_FORCE_ENGLISH=true`, a non-English OpenRouter response is rejected and the API falls back to deterministic templates. This avoids a second provider request.

If you already have stored results that contain non-English text (for example, older `qwen2.5:1.5b` outputs), run:
```bash
php artisan palms:enforce-english-readings
```
