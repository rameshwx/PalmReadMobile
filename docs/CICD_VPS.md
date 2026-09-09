# CI/CD: Deploy Backend To VPS

This repository includes a GitHub Actions workflow that deploys backend changes
using `rsync` and the remote deployment script. No host address, username, path,
password, or private key is stored in this repository.

## Required GitHub Actions secrets

Configure these in the repository or environment secret store:

- `VPS_HOST`: deployment host or DNS name
- `VPS_USER`: SSH user
- `VPS_PATH`: deployment directory
- `VPS_SSH_PRIVATE_KEY`: private key that can log in as `VPS_USER`

The workflow passes these values to commands at runtime. Do not replace the
secret references in `.github/workflows/deploy_vps.yml` with literals.

## SSH key setup

Generate a dedicated CI key outside the repository:

```bash
ssh-keygen -t ed25519 -C "palmreadmobile-ci" -f ~/.ssh/palmreadmobile_ci
```

Install the public key on the deployment host through an approved secure access
procedure. Store only the private key contents in `VPS_SSH_PRIVATE_KEY` and keep
the local key files out of Git.

## Deployment flow

On a qualifying push to `main`, the workflow:

1. Checks out the repository.
2. Loads the SSH private key from GitHub Actions secrets.
3. Adds the secret host to the runner's temporary `known_hosts` file.
4. Synchronizes source while excluding `.env` and runtime directories.
5. Runs `scripts/deploy/deploy_remote.sh` on the deployment host.

The remote script rebuilds the Laravel, worker, CV, and Nginx services, runs
migrations and cache clearing, and performs health checks.

## Secret handling

- Keep root and Laravel `.env` files on the deployment host only.
- Keep Firebase service-account JSON on the deployment host only.
- Do not pass passwords on command lines or commit them to documentation.
- Rotate credentials if they have appeared in repository history.
