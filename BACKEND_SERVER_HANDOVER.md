# PalmReadMobile Backend Server Handover

Last verified: 2026-02-11 (UTC)

## 1) Server Access

| Item | Value |
|---|---|
| Public IPv4 | `51.255.201.31` |
| SSH username | `ubuntu` |
| SSH password | `W5bw5XBuWMQP` |
| Hostname | `vps-31f3f47c` |
| OS | Ubuntu 25.04 (Plucky Puffin) |

SSH login:

```bash
ssh ubuntu@51.255.201.31
```

Then enter password:

```text
W5bw5XBuWMQP
```

## 2) Current Deployment Model

This server is running the project in Docker Compose mode.

- Host-level app stack is containerized.
- PHP, Composer, Nginx, Redis, and Postgres are inside containers (not installed as host binaries).
- Project root on server: `/home/ubuntu/PalmReadMobile`

## 3) Installed Software and Runtime Versions

### Host-level tools (installed)

| Tool | Version / Path |
|---|---|
| Docker Engine | `Docker version 28.2.2` |
| Docker Compose | `v2.37.1` |
| Git | `/usr/bin/git` |
| Python3 | `/usr/bin/python3` |
| UFW | `/usr/sbin/ufw` |

### Host-level tools (not installed natively)

- `php`
- `composer`
- `nginx`
- `redis-server`
- `psql`
- `pip3`

### Container runtimes (verified)

| Service | Version |
|---|---|
| Laravel app container PHP | `8.3.30` |
| Laravel app container Composer | `2.9.5` |
| Laravel framework | `12.51.0` |
| CV container Python | `3.11.14` |
| CV container FastAPI | `0.116.1` |
| CV container OpenCV | `4.13.0` |
| CV container NumPy | `2.0.2` |
| Postgres container | `15.15` |
| Redis container | `7.4.7` |

## 4) Running Services and Exposed Ports

`docker compose ps` currently shows:

| Service | Container | Port exposure |
|---|---|---|
| API Web | `palmread_nginx` | `0.0.0.0:8080 -> 80` |
| Laravel app | `palmread_laravel_app` | internal `9000` |
| Laravel worker | `palmread_laravel_worker` | internal |
| CV service | `palmread_cv_service` | `0.0.0.0:8001 -> 8001` |
| Ollama LLM | `palmread_ollama` | internal `11434` |
| PostgreSQL | `palmread_postgres` | `0.0.0.0:5432 -> 5432` |
| Redis | `palmread_redis` | `0.0.0.0:6379 -> 6379` |

Live URLs:

- API base: `http://51.255.201.31:8080`
- CV health: `http://51.255.201.31:8001/health`

## 5) Project File Locations

### Root

- Repo root: `/home/ubuntu/PalmReadMobile`
- Root compose file: `/home/ubuntu/PalmReadMobile/docker-compose.yml`
- Root env file: `/home/ubuntu/PalmReadMobile/.env`
- Root README: `/home/ubuntu/PalmReadMobile/README.md`

### Laravel API

- Laravel project: `/home/ubuntu/PalmReadMobile/laravel_api`
- Laravel env: `/home/ubuntu/PalmReadMobile/laravel_api/.env`
- Routes: `/home/ubuntu/PalmReadMobile/laravel_api/routes/api.php`
- Queue job: `/home/ubuntu/PalmReadMobile/laravel_api/app/Jobs/ProcessPalmReadJob.php`
- Reading logic: `/home/ubuntu/PalmReadMobile/laravel_api/app/Services/Reading`
- API controllers: `/home/ubuntu/PalmReadMobile/laravel_api/app/Http/Controllers/Api`
- Local image storage (inside repo bind): `/home/ubuntu/PalmReadMobile/laravel_api/storage/app/palms`

### CV service

- CV project: `/home/ubuntu/PalmReadMobile/cv_service`
- Entry point: `/home/ubuntu/PalmReadMobile/cv_service/app/main.py`
- Pipeline modules: `/home/ubuntu/PalmReadMobile/cv_service/app/pipeline`
- Python deps: `/home/ubuntu/PalmReadMobile/cv_service/requirements.txt`

### Flutter app

- Flutter project: `/home/ubuntu/PalmReadMobile/flutter_app`
- App config: `/home/ubuntu/PalmReadMobile/flutter_app/lib/core/config/app_config.dart`

### Shared Docker volume paths (inside containers)

- Palm images volume mounted at:
  - `/var/www/html/storage/app/palms`
  - `/data/palms`

## 6) Important Config Values (Current)

From `/home/ubuntu/PalmReadMobile/.env`:

- `LARAVEL_DB_CONNECTION=pgsql`
- `LARAVEL_DB_HOST=postgres`
- `LARAVEL_DB_PORT=5432`
- `LARAVEL_DB_DATABASE=palmread`
- `LARAVEL_DB_USERNAME=palmread`
- `LARAVEL_DB_PASSWORD=palmread`
- `LARAVEL_QUEUE_CONNECTION=redis`
- `LARAVEL_REDIS_HOST=redis`
- `LARAVEL_CV_SERVICE_BASE_URL=http://cv_service:8001`
- `LARAVEL_PALM_STORAGE_DISK=palms`
- `LARAVEL_PALM_IMAGE_RETENTION_DAYS=30`
- `LARAVEL_PALM_UPLOAD_MAX_MB=8`
- `LARAVEL_PALM_LLM_ENABLED=true`
- `LARAVEL_PALM_LLM_BASE_URL=http://ollama:11434`
- `LARAVEL_PALM_LLM_MODEL=qwen2.5:1.5b`
- `LARAVEL_PALM_LLM_TIMEOUT_SECONDS=60`
- `LARAVEL_PALM_LLM_NUM_PREDICT=160`
- `CV_MAX_IMAGE_SIDE=1600`
- `CV_ROI_SIZE=512`
- `CV_TIMEOUT_MS=8000`
- `CV_NUM_THREADS=1`

From `/home/ubuntu/PalmReadMobile/laravel_api/.env` (key items):

- `APP_ENV=local`
- `APP_URL=http://localhost:8080`
- `DB_CONNECTION=pgsql`
- `DB_DATABASE=palmread`
- `QUEUE_CONNECTION=redis`
- `REDIS_HOST=redis`
- `CV_SERVICE_BASE_URL=http://cv_service:8001`

## 7) Backend Dependencies

### Laravel (`laravel_api/composer.json`)

Main packages:

- `laravel/framework:^12.0`
- `laravel/sanctum:^4.0`
- `predis/predis:^3.3`

Dev packages:

- `phpunit/phpunit:^11.5`
- `mockery/mockery:^1.6`
- `laravel/pint:^1.18`
- `fakerphp/faker:^1.23`

### CV service (`cv_service/requirements.txt`)

- `fastapi==0.116.1`
- `uvicorn[standard]==0.35.0`
- `numpy==2.0.2`
- `opencv-python-headless==4.11.0.86`
- `mediapipe==0.10.14`
- `pydantic==2.11.7`
- `pydantic-settings==2.10.1`
- `pytest==8.3.5`

## 8) Daily Operations

From `/home/ubuntu/PalmReadMobile`:

Start/stop:

```bash
docker compose up -d
docker compose down
```

Rebuild after code/dependency changes:

```bash
docker compose up --build -d
```

Check status:

```bash
docker compose ps
```

Tail logs:

```bash
docker compose logs -f laravel_app
docker compose logs -f laravel_worker
docker compose logs -f cv_service
docker compose logs -f nginx
```

Run Laravel commands:

```bash
docker compose exec -T laravel_app php artisan migrate
docker compose exec -T laravel_app php artisan optimize:clear
docker compose exec -T laravel_app php artisan test
```

Health checks:

```bash
curl http://localhost:8080/api/health
curl http://localhost:8001/health
```

## 9) Fresh Setup From Scratch (Same Docker-Based Architecture)

### Step 1: Provision server

1. Create Ubuntu VM.
2. Open inbound ports as needed: `22`, `8080`, `8001` (or put behind reverse proxy and TLS).

### Step 2: Install prerequisites on host

```bash
sudo apt update
sudo apt install -y git docker.io docker-compose-v2
sudo usermod -aG docker $USER
newgrp docker
```

### Step 3: Get project code

```bash
cd /home/ubuntu
git clone <your-repo-url> PalmReadMobile
cd PalmReadMobile
cp .env.example .env
```

### Step 4: Configure env

Edit `.env` (root) and set:

- DB credentials
- API/CV URLs
- retention and upload limits
- any production overrides

Then ensure Laravel env exists:

```bash
cp laravel_api/.env.example laravel_api/.env
```

### Step 5: Build and start stack

```bash
docker compose up --build -d
```

### Step 6: Initialize Laravel app

```bash
docker compose exec -T laravel_app composer install
docker compose exec -T laravel_app php artisan key:generate
docker compose exec -T laravel_app php artisan migrate --force
docker compose exec -T laravel_app php artisan optimize:clear
```

### Step 7: Verify services

```bash
docker compose ps
curl http://localhost:8080/api/health
curl http://localhost:8001/health
```

### Step 8: Optional hardening

1. Put Nginx/Traefik in front with HTTPS on `443`.
2. Restrict DB/Redis/CV ports from public internet.
3. Rotate server password and switch to SSH key auth.
4. Enable firewall rules.

## 10) Current Security and Infra Notes

- UFW status: `inactive`.
- DB (`5432`) and Redis (`6379`) are publicly mapped in current compose; restrict these in production.
- SSH password auth is in use.
- Swap is `0B` (no swap configured).
- Disk currently has ample free space (`~67G` free on `/`).

Recommended immediate actions:

1. Rotate SSH password and remove plaintext credentials from shared docs.
2. Move to SSH key auth and disable password login.
3. Remove public exposure of `5432` and `6379`.
4. Add TLS termination and domain-based access.

## 11) Deployment Update Workflow

Typical backend update process:

```bash
cd /home/ubuntu/PalmReadMobile
git pull
docker compose up --build -d laravel_app laravel_worker cv_service nginx
docker compose exec -T laravel_app php artisan migrate --force
docker compose exec -T laravel_app php artisan optimize:clear
docker compose ps
```

If only PHP code changed (no image rebuild needed), a restart is usually enough:

```bash
docker compose restart laravel_app laravel_worker nginx
```

## 12) Quick Troubleshooting

401 from app:

1. Verify token handling in app.
2. Check `laravel_app` logs.
3. Confirm Sanctum config and `Authorization: Bearer <token>`.

Uploads failing:

1. Check `PALM_UPLOAD_MAX_MB`.
2. Verify `laravel_api/storage/app/palms` permissions.
3. Check `laravel_worker` logs for queued job errors.

Jobs stuck queued:

1. Confirm `laravel_worker` is running.
2. Confirm Redis service health.
3. Inspect failed jobs:

```bash
docker compose exec -T laravel_app php artisan queue:failed
```

CV analysis failures:

1. Check `cv_service` logs.
2. Confirm image path exists in shared volume (`/var/www/html/storage/app/palms`).
3. Confirm `CV_SERVICE_BASE_URL` is reachable from Laravel container.

LLM fallback observed:

1. Check `storage/logs/laravel.log` for `LLM reading generation failed`.
2. Confirm model is pulled:

```bash
docker compose exec -T ollama ollama list
```
3. Confirm Laravel env values:

```bash
docker compose exec -T laravel_app php -r "echo getenv('PALM_LLM_ENABLED').PHP_EOL; echo getenv('PALM_LLM_MODEL').PHP_EOL;"
```
