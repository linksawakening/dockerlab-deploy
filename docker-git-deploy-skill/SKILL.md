---
name: docker-git-deploy-skill
description: Hermes agent skill for docker-git-deploy. Deploy Docker Compose services with pull-based GitOps. Helps the user generate a pure-config deployment repo, add services, test locally, and bootstrap a production host that self-heals with autoheal.
version: 4.0.0
author: linksawakening
license: MIT
metadata:
  hermes:
    tags: [devops, docker, docker-compose, gitops, self-hosting, homelab, deployment]
---

# docker-git-deploy-skill

Agent-side skill for [docker-git-deploy](https://github.com/linksawakening/docker-git-deploy).
Use it when a user wants pull-based GitOps deployment for Docker Compose
services on a homelab or production host.

## What docker-git-deploy is

A lightweight pull-based GitOps tool for a single host. The agent edits a
**deployment repo** (pure config); the production host runs a systemd timer that
pulls the repo and reconciles the Docker Compose stack. The agent never needs
SSH or Docker access to the host after the one-line bootstrap.

**This repository is the skill and its tooling only** — it has no compose config
at its root. Everything lives under `docker-git-deploy-skill/`, and the
canonical example is a bundled starter at `assets/starter/`.

| Part | Where | Contains |
|------|-------|----------|
| Skill + framework | `docker-git-deploy-skill/` | `SKILL.md`, `scripts/`, `assets/`, `references/` |
| Starter / example | `docker-git-deploy-skill/assets/starter/` | Pure-config example (autoheal); also the CI fixture |
| User deployment repo | the user's own repo | Generated from the starter; pure config |

## When to use this skill

- User wants to deploy Docker services via GitOps / pull-based deployment.
- User mentions `docker-git-deploy`.
- User wants to add/update/remove a service on a docker-git-deploy host.
- User reports the production host is not deploying changes.

## Install the skill

```bash
npx skills add https://github.com/linksawakening/docker-git-deploy --skill docker-git-deploy-skill -a hermes-agent -g -y --copy
```

## Core architecture

```text
┌─────────────────┐  push   ┌──────────────────┐  pull   ┌────────────────────┐
│  Agent / user   │────────▶│  deployment repo │◀────────│  production host   │
│  edits config   │         │  (pure config)   │         │  timer → reconcile │
└─────────────────┘         └──────────────────┘         └────────────────────┘
        └──────── framework: docker-git-deploy-skill/ (install.sh, CLI, ─────────┘
                  systemd units, starter, skill)
```

The deploy is a **declarative reconcile**: `docker compose up -d --remove-orphans
--wait` runs every tick (so the stack converges on the first tick after install
and self-heals crashes); images are pulled only on a new commit or `--force`; a
failed update rolls back to the previous commit.

## Repo layout

```text
docker-git-deploy/                       # this repo = the skill package
├── README.md · LICENSE · .gitignore
├── .github/workflows/
│   ├── validate.yaml                    # lint the starter compose
│   └── install-test.yaml                # install → deploy → assert healthy
└── docker-git-deploy-skill/
    ├── SKILL.md                          # <-- the only SKILL.md in the repo
    ├── references/
    │   ├── prerequisites.md
    │   ├── security-model.md
    │   ├── design-constraints.md
    │   └── troubleshooting.md
    ├── scripts/
    │   ├── install.sh                    # one-command production install
    │   ├── docker-git-deploy             # CLI (deploy/validate/test/logs/status)
    │   ├── init-deployment.sh            # generate a deployment repo from the starter
    │   └── validate-repo-structure.sh    # check a deployment repo is pure config
    └── assets/
        ├── systemd/                      # docker-git-deploy.service.in / .timer.in
        └── starter/                      # pure-config example == starter == CI fixture
```

## Agent adoption flow

### 1. Explain prerequisites
Target host needs: Linux + systemd, Docker Engine running, Docker Compose plugin
**v2.1.1+** (the deploy uses `up --wait`), git, curl, and outbound HTTPS to
GitHub. The agent cannot install these; point the user to
`references/prerequisites.md`.

### 2. Interview the user

| Question | Default | Used for |
|----------|---------|----------|
| Production host name? | none | docs / repo name |
| Deployment repo name? | `<host>-deploy` | private repo name |
| GitHub org/user? | user's own | repo URLs |
| Deployment directory on host? | `/opt/<repo>` | clone target |
| Deploy user? | `docker-git-deploy` (unprivileged) | systemd `User=` |
| Poll interval? | `5min` | systemd timer |
| Initial services? | autoheal (from starter) | service definitions |

### 3. Generate the deployment repo

```bash
FRAMEWORK=~/.hermes/skills/devops/docker-git-deploy/docker-git-deploy-skill
"$FRAMEWORK/scripts/init-deployment.sh" \
  --target-dir ~/my-host-deploy \
  --repo-name my-host-deploy \
  --host-name my-host \
  --org my-github-org
```

Run with no flags for interactive prompts. This copies `assets/starter/`
(compose + autoheal + `.env.example` + `.gitignore`) and writes a host-specific
README with the bootstrap command.

### 4. Add or adjust services
- Create `services/<name>/compose.yaml` in the deployment repo.
- Add its variables to `.env.example`.
- Add `- services/<name>/compose.yaml` to the `include:` list in `compose.yaml`.
- To have autoheal watch it, give the service `labels: [autoheal=true]` and a
  `healthcheck:`.

### 5. Test locally
```bash
cd <deployment-repo>
docker compose config >/dev/null && echo Valid
"$FRAMEWORK/scripts/validate-repo-structure.sh"   # confirm it is pure config
```

### 6. Push the deployment repo
```bash
cd <deployment-repo>
git init && git add . && git commit -m "initial docker-git-deploy deploy"
git remote add origin https://github.com/<org>/<repo>.git
git push -u origin main
```

### 7. Bootstrap the production host (run as root)
```bash
curl -fsSL https://raw.githubusercontent.com/<org>/docker-git-deploy/main/docker-git-deploy-skill/scripts/install.sh | \
  bash -s -- \
    --deployment-repo https://github.com/<org>/<repo>.git \
    --deployment-dir /opt/<repo> \
    --user docker-git-deploy \
    --interval 5min
```
For SSH, use `git@github.com:<org>/<repo>.git`. For a privileged deploy, use
`--user root`. Then the user creates `.env`:
```bash
sudo cp /opt/<repo>/.env.example /opt/<repo>/.env
sudo nano /opt/<repo>/.env
```
The deploy is skipped until `.env` exists; the next timer tick then converges.

### 8. Confirm
```bash
systemctl list-timers docker-git-deploy.timer
journalctl -u docker-git-deploy.service -f
```

## Adding a service later
1. Create `services/<name>/compose.yaml`; add env to `.env.example`; add the
   include to root `compose.yaml`.
2. `docker compose config >/dev/null` to validate.
3. Commit and push. The host reconciles on the next tick.

## Removing a service
1. Remove its line from the `include:` list in `compose.yaml` (optionally delete
   the directory).
2. Push. `up -d --remove-orphans` cleans up the stopped service automatically.

## Common pitfalls
- Forgetting to create `.env` on the host (deploy is skipped until it exists).
- Committing a real `.env`. Ensure `.gitignore` includes `.env`.
- Using legacy `docker-compose` instead of the `docker compose` plugin.
- Running the install command without root.
- autoheal not restarting a container: it needs **both** `autoheal=true` and a
  `healthcheck:`.
- Putting scripts or systemd units in the deployment repo — keep it pure config;
  all tooling lives in `docker-git-deploy-skill/`.
- More than one `SKILL.md` in the repo. There must be exactly one, here.
- Using `docker/setup-docker-action@v4` in CI (iptables breakage).

## References
- `references/prerequisites.md` — host requirements
- `references/security-model.md` — pull model, credential scopes, docker.sock caveat
- `references/design-constraints.md` — architectural guardrails
- `references/troubleshooting.md` — failure modes, `--wait`/rollback, CI iptables
- `scripts/validate-repo-structure.sh` — verify a deployment repo is pure config
