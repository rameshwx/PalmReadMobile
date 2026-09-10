# PalmReadMobile Backend Server Handover

This document intentionally contains no server addresses, passwords, private keys,
hostnames, or deployment-specific filesystem paths.

## Server access

- VPS host: configure through the private `VPS_HOST` deployment secret.
- SSH user: configure through the private `VPS_USER` deployment secret.
- SSH authentication: use an SSH key stored outside Git and in the CI secret store.
- Password authentication is not documented or supported here.

Example using private values supplied at invocation time:

```bash
ssh "${VPS_USER}@${VPS_HOST}"
```

## Deployment model

The backend runs as a Docker Compose stack containing:

- Laravel API and queue worker
- Nginx web server
- Redis queue/cache
- PostgreSQL database
- CPU-only CV service
- Optional OpenRouter humanization through the Laravel app and worker

The deployment path is supplied through the private `VPS_PATH` secret. It must not
be committed to this repository.

## Service layout

| Service | Exposure |
|---|---|
| Nginx API web server | internal port 80; published only by the local override |
| Laravel app | internal PHP-FPM port |
| Laravel worker | internal |
| CV service | internal port 8001; published only by the local override |
| OpenRouter | outbound HTTPS from Laravel app/worker |
| PostgreSQL | private Compose service; loopback-only in local development |
| Redis | private Compose service; loopback-only in local development |

Use the deployment host and application scheme supplied by the environment when
constructing API, admin, and health URLs. Do not add those values to Git.

## Required environment configuration

Create the root `.env` file on the deployment host from `.env.example`. Keep it
outside Git and set the real values there, including:

- `LARAVEL_DB_PASSWORD`
- `LARAVEL_MAIL_PASSWORD`, when SMTP is enabled
- `LARAVEL_PALM_ADMIN_PASSWORD`, when the admin dashboard is enabled
- `LARAVEL_PALM_FCM_SERVICE_ACCOUNT_PATH` or
  `LARAVEL_PALM_FCM_SERVICE_ACCOUNT_BASE64`
- `LARAVEL_PALM_OPENROUTER_API_KEY`, when OpenRouter humanization is enabled
- `LARAVEL_APP_URL`, `LARAVEL_CV_SERVICE_BASE_URL`, and any deployment API URL

The Firebase service-account JSON must remain on the deployment host only. It is
ignored by Git and must never be pasted into documentation, issues, or logs.

## Deployment commands

Run these commands from the private deployment path represented by `$VPS_PATH`:

```bash
docker compose -f docker-compose.yml -f docker-compose.local.yml up --build -d
docker compose -f docker-compose.yml -f docker-compose.local.yml exec -T laravel_app composer install
docker compose -f docker-compose.yml -f docker-compose.local.yml exec -T laravel_app php artisan key:generate
docker compose -f docker-compose.yml -f docker-compose.local.yml exec -T laravel_app php artisan migrate --force
docker compose -f docker-compose.yml -f docker-compose.local.yml exec -T laravel_app php artisan optimize:clear
docker compose -f docker-compose.yml -f docker-compose.local.yml ps
```

Health checks should use the configured application host and the local container
endpoints. Do not publish database or Redis ports publicly.

## Security checklist

1. Store all passwords, service-account material, and deployment paths outside Git.
2. Use SSH keys and disable SSH password authentication.
3. Restrict PostgreSQL, Redis, and CV service exposure to trusted interfaces.
4. Put the public application behind TLS and a controlled reverse proxy.
5. Rotate any credential that has ever appeared in repository history.
6. Keep `.env`, Firebase service accounts, runtime storage, and Git metadata out of
   deployment synchronization.
