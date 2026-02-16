# PalmReadMobile

Production-oriented monorepo for palm reading with deterministic CPU CV, Laravel API, and Flutter mobile app.

## Components
- `flutter_app/`: Flutter Android/iOS app (Riverpod + Dio).
- `laravel_api/`: Laravel REST API with Sanctum + Redis queue.
- `cv_service/`: FastAPI + OpenCV CPU-only CV service.

## URL Prefixes (Important)
This stack serves the mobile + admin experience under the `/palmread` path:

- API base: `http://<host>:8080/palmread/api`
- Admin dashboard: `http://<host>:8080/palmread/admin`
- Health: `http://<host>:8080/up`
- CV health: `http://<host>:8001/health`

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
   curl http://localhost:8080/palmread/api/health
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

## CI/CD (Backend -> VPS)
GitHub Actions workflow is included for deploying backend changes to your VPS:
- `docs/CICD_VPS.md`

## Auth (OTP)
Recommended auth flow is email OTP:

1. `POST /palmread/api/auth/otp/request`
2. `POST /palmread/api/auth/otp/verify` -> returns Sanctum token

Legacy endpoints still exist (not used by the refreshed app UI):
- `POST /palmread/api/auth/register`
- `POST /palmread/api/auth/login`

## Push Notifications (FCM)
Backend uses **FCM HTTP v1** (service account), not the legacy server-key method.

1. Create/obtain a Firebase service-account JSON for project `palm-read-5cfa3`.
2. Place it on the server at `laravel_api/storage/app/firebase/service-account.json` (this path is git-ignored).
3. Set in root `.env` (Docker compose):
   - `LARAVEL_PALM_FCM_PROJECT_ID=palm-read-5cfa3`
   - `LARAVEL_PALM_FCM_SERVICE_ACCOUNT_PATH=/var/www/html/storage/app/firebase/service-account.json`
4. Restart Laravel containers and clear caches:
   ```bash
   docker compose exec -T laravel_app php artisan optimize:clear
   docker compose restart laravel_app laravel_worker
   ```

For Flutter, after changing Android package to `com.rameshwx.palm_read_mobile`, prefer generating correct Firebase config via:
```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=palm-read-5cfa3
```

## Acceptance Smoke Flow
1. Request OTP with `POST /palmread/api/auth/otp/request`.
2. Verify OTP with `POST /palmread/api/auth/otp/verify` and use `Authorization: Bearer <token>`.
3. Upload image via `POST /palmread/api/palm-reads`.
4. Poll `GET /palmread/api/palm-reads/{id}` until `completed`.
5. (Optional) Fetch overlay from `GET /palmread/api/palm-reads/{id}/overlay`.
6. Submit feedback via `POST /palmread/api/palm-reads/{id}/feedback`.
