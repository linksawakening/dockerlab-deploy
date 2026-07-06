---
name: docker-git-deploy-skill
description: Hermes agent guide for docker-git-deploy. Helps a user adopt the docker-git-deploy GitOps framework, generate a deployment repo, define services, test locally, and bootstrap a production host.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [devops, docker, docker-compose, gitops, homelab, deployment, agent-guide]
---

# docker-git-deploy-skill

Agent-side guide for [docker-git-deploy](https://github.com/linksawakening/docker-git-deploy). Use this skill when a user wants to set up pull-based GitOps deployment for Docker Compose services on a homelab or production host.

## When to use this skill

- User says they want to deploy Docker services via GitOps.
- User mentions `docker-git-deploy` or pull-based deployment.
- User wants to add/update/remove a service on a docker-git-deploy-managed host.
- User reports that the production host is not deploying changes.

## Install the skill

```bash
npx skills add https://github.com/linksawakening/docker-git-deploy --skill docker-git-deploy-skill -a hermes-agent -g -y --copy
```

Then follow this guide to interview the user, generate the deployment repo, test locally, and provide production install commands.

## What docker-git-deploy is

A lightweight GitOps tool:

- **Framework repo** (`docker-git-deploy`) is installed once on the production host. It polls a deployment repo and runs `docker compose`.
- **Deployment repo** (e.g. `ribeedocker-deploy`) is pure configuration — `compose.yaml`, `.env.example`, `services/`.
- The agent edits the deployment repo; the production host pulls changes and applies them.

The agent never needs SSH/Docker access to the production host after the one-line bootstrap.

## Agent adoption flow

### 1. Explain prerequisites

Before anything else, the target host must have:

- Linux with systemd
- Docker Engine running
- Docker Compose plugin (`docker compose`)
- git, curl
- Outbound HTTPS to GitHub

Tell the user the agent cannot install these on the production host; the host administrator must provide them. Point them to the framework's `docker-git-deploy/references/prerequisites.md`.

### 2. Interview the user

Ask for:

| Question | Default | Used for |
|----------|---------|----------|
| What is the production host name? | none | README filename, docs |
| Deployment user on host? | `docker-git-deploy` | systemd service user |
| Deployment directory on host? | `/opt/<host>-deploy` | clone target |
| Poll interval? | `5min` | systemd timer |
| GitHub org/user for repos? | user's own | repo URLs |
| Deployment repo name? | `<host>-deploy` | private repo name |
| Initial services? | none | service definitions |
| Read access method? | HTTPS | clone URL |

### 3. Generate the deployment repo

Use the framework's generator:

```bash
npx skills add https://github.com/linksawakening/docker-git-deploy --skill docker-git-deploy-skill -a hermes-agent -g -y --copy
cd ~/.hermes/skills/devops/docker-git-deploy
./docker-git-deploy/scripts/init-deployment.sh
```

Answer the prompts with the user's choices.

### 4. Add service definitions

Copy service templates from `~/.hermes/skills/devops/docker-git-deploy/docker-git-deploy/templates/services/<name>/` into the new deployment repo's `services/` directory. Update root `compose.yaml` to include them. Update `.env.example` with required variables.

Available catalog:

- `docker-git-deploy/templates/services/searxng/` — SearXNG meta-search engine
- `docker-git-deploy/templates/services/example-service/` — minimal nginx example

### 5. Test locally

In the generated deployment repo, use the framework's CLI directly:

```bash
FRAMEWORK_DIR=~/.hermes/skills/devops/docker-git-deploy/docker-git-deploy \
"$FRAMEWORK_DIR/scripts/docker-git-deploy" validate
FRAMEWORK_DIR=~/.hermes/skills/devops/docker-git-deploy/docker-git-deploy \
"$FRAMEWORK_DIR/scripts/docker-git-deploy" test
```

Or run `docker compose config` directly.

### 6. Push the deployment repo

```bash
cd <deployment-repo>
git init
git add .
git commit -m "initial docker-git-deploy deploy"
git remote add origin https://github.com/<org>/<repo>.git
git push -u origin main
```

### 7. Give the production bootstrap command

Generate a one-line install command for the user to run as root on the production host:

```bash
curl -fsSL https://raw.githubusercontent.com/<org>/docker-git-deploy/main/docker-git-deploy/scripts/install.sh | \
bash -s -- \
 --deployment-repo https://github.com/<org>/<repo>.git \
 --deployment-dir /opt/<host>-deploy \
 --user docker-git-deploy \
 --interval 5min
```

If the user prefers SSH:

```bash
curl -fsSL https://raw.githubusercontent.com/<org>/docker-git-deploy/main/docker-git-deploy/scripts/install.sh | \
bash -s -- \
 --deployment-repo git@github.com:<org>/<repo>.git \
 --deployment-dir /opt/<host>-deploy \
 --user docker-git-deploy \
 --interval 5min
```

Then the user must:

```bash
sudo cp /opt/<host>-deploy/.env.example /opt/<host>-deploy/.env
sudo nano /opt/<host>-deploy/.env
```

### 8. Confirm production deployment

Ask the user to run on the production host:

```bash
sudo systemctl list-timers docker-git-deploy.timer
sudo journalctl -u docker-git-deploy.service -f
```

Then confirm the timer is active and the first deploy succeeded.

## Adding a new service later

1. In the deployment repo, create `services/<name>/compose.yaml`.
2. Add required env vars to `.env.example`.
3. Add the service to root `compose.yaml`.
4. Run `docker-git-deploy validate` and `docker-git-deploy test` from the framework.
5. Commit and push.
6. The production host will pull and apply on the next timer tick.

## Removing a service

1. Remove the `include` from root `compose.yaml`.
2. Optionally remove the service directory.
3. Push.
4. `docker compose up -d --remove-orphans` will clean up removed services automatically.

## Common pitfalls

- Forgetting to create `.env` on the production host after bootstrap.
- Committing real `.env` files to Git. Ensure `.gitignore` includes `.env`.
- Using `docker-compose` (legacy binary) instead of `docker compose` (plugin).
- Running the install command without root.
- Health check URL not matching the actual service port.

## References

- `docker-git-deploy/references/agent-flow.md` — decision tree for the agent
- `docker-git-deploy/references/production-install.md` — copy-paste install commands
- `docker-git-deploy/references/service-catalog.md` — service definitions and their requirements
