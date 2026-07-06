# Design Constraints — docker-git-deploy

These constraints are the result of hard-won architecture decisions during the design of docker-git-deploy. Future edits must preserve them.

## 1. Deployment repo = pure config

A deployment repo contains **only**:

- `compose.yaml`
- `.env.example`
- `.env` (on the host, ignored in Git)
- `.gitignore`
- `README.md`
- `.github/workflows/` (optional, minimal)
- `services/<name>/compose.yaml` and service data

It must **never** contain:

- Bootstrap/install scripts
- `deploy.sh`, `validate.sh`, `health-check.sh`, `test-local.sh`
- Systemd units or timers
- Any executable tooling

All of that belongs in the framework (`docker-git-deploy-skill/`).

## 2. Framework lives in a named subfolder

The framework and agent skill live under a subfolder named after the skill — here, `docker-git-deploy-skill/`. The repo root is reserved for the canonical example deployment.

## 3. Canonical example in the same repo, real deployments separate

This repository is both framework and canonical example. The top-level files are the example deployment; `docker-git-deploy-skill/` is the tool.

For a real production host, generate a **separate** deployment repo using `docker-git-deploy-skill/scripts/init-deployment.sh`.

## 4. CI must exercise the install path

Every change to the framework must be validated by a workflow that runs `docker-git-deploy-skill/scripts/install.sh` against the repo and then invokes `docker-git-deploy validate` and `docker-git-deploy deploy`. Static compose validation alone is not enough.
