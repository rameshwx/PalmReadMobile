# Coolify deployment

PalmReadMobile production is deployed by Coolify from the GitHub App-backed
repository `rameshwx/PalmReadMobile`.

## Resource configuration

- Project: `PalmReadMobile`
- Environment: `production`
- Repository: `rameshwx/PalmReadMobile`
- Branch: `main`
- Build pack: Docker Compose
- Base directory: `/`
- Compose file: `/docker-compose.yml`
- Public service: `nginx`, internal port `80`
- Domain: `https://palm.uxi.asia`
- HTTP-to-HTTPS redirect: enabled
- `www` alias: disabled
- Auto Deploy: enabled through the GitHub App webhook

The production Compose file deliberately publishes no host ports for PostgreSQL,
Redis, CV, or Nginx. Coolify routes the exact domain to Nginx over the private
Compose network. Use `docker-compose.local.yml` only for loopback development.

## Private variables

Set these in Coolify's production environment. Values containing credentials or
service-account material must remain private and must never be committed:

- `LARAVEL_APP_ENV=production`
- `LARAVEL_APP_DEBUG=false`
- `LARAVEL_APP_URL=https://palm.uxi.asia`
- `LARAVEL_APP_KEY`
- `LARAVEL_DB_PASSWORD`
- `LARAVEL_MAIL_HOST`, `LARAVEL_MAIL_PORT`, `LARAVEL_MAIL_USERNAME`,
  `LARAVEL_MAIL_PASSWORD`, `LARAVEL_MAIL_ENCRYPTION`, and sender values
- `LARAVEL_PALM_ADMIN_USERNAME` and `LARAVEL_PALM_ADMIN_PASSWORD`
- `LARAVEL_PALM_FCM_PROJECT_ID` and
  `LARAVEL_PALM_FCM_SERVICE_ACCOUNT_BASE64`
- `LARAVEL_PALM_LLM_ENABLED=true`
- `LARAVEL_PALM_OPENROUTER_API_KEY`
- `LARAVEL_PALM_OPENROUTER_BASE_URL=https://openrouter.ai/api/v1`
- `LARAVEL_PALM_OPENROUTER_MODEL`

The private service defaults should remain `postgres`, `redis`, and
`http://cv_service:8001` for the database, queue/cache, and CV service.

## Post-deployment command

Run on the `laravel_app` container after deployment:

```text
composer install --no-interaction --prefer-dist --optimize-autoloader && php artisan migrate --force && php artisan optimize:clear
```

## Verification

```bash
curl -fsS https://palm.uxi.asia/
curl -fsS https://palm.uxi.asia/palmread/api/health
curl -i https://palm.uxi.asia/palmread/admin/
```

The first two requests must return HTTP 200. The admin request should return an
authentication challenge when no credentials are supplied. Check CV health from
inside the private Compose network with `curl http://cv_service:8001/health`.

Confirm that the deployment has healthy app, worker, Nginx, PostgreSQL, Redis,
and CV containers, and that the named `postgres_data` and `palm_images` volumes
remain attached. A subsequent non-empty push to `main` should create a new
Coolify deployment through the GitHub App webhook.
