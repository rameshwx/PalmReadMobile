# CI/CD: Deploy Backend To VPS

This repo includes a GitHub Actions workflow that deploys backend changes to the VPS by `rsync` + a remote deploy script.

## What It Does

On push to `main` (backend paths only), the workflow:

1. Syncs repo files to the VPS directory via `rsync` (excluding `.env` and runtime directories).
2. Runs `scripts/deploy/deploy_remote.sh` on the VPS to:
   - `docker compose up -d --build` (Laravel app/worker, CV service, nginx)
   - `composer install`
   - `php artisan migrate --force`
   - `php artisan optimize:clear`
   - health checks

## Required GitHub Secrets

Add these in GitHub: `Settings -> Secrets and variables -> Actions`.

- `VPS_HOST`: `51.255.201.31`
- `VPS_USER`: `ubuntu`
- `VPS_PATH`: `/home/ubuntu/PalmReadMobile`
- `VPS_SSH_PRIVATE_KEY`: an SSH private key that can log in as `ubuntu`

## SSH Key Setup (Recommended)

1. Generate a key on your local machine:

```bash
ssh-keygen -t ed25519 -C "palmreadmobile-ci" -f ~/.ssh/palmreadmobile_ci
```

2. Add the public key to the VPS:

```bash
ssh ubuntu@51.255.201.31 "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
cat ~/.ssh/palmreadmobile_ci.pub | ssh ubuntu@51.255.201.31 "cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

3. In GitHub Secrets, set `VPS_SSH_PRIVATE_KEY` to the contents of `~/.ssh/palmreadmobile_ci`.

## Notes

- The deploy workflow intentionally does not sync `.env` files.
- If you change Dockerfiles or Python deps, the deploy script rebuilds images via `--build`.
- If you want to deploy only certain services, edit `scripts/deploy/deploy_remote.sh`.

