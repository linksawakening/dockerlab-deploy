---
name: docker-git-deploy-skill
description: Agent skill for docker-git-deploy. Deploy Docker Compose services with pull-based GitOps. Helps the user generate a pure-config deployment repo, add services, test locally, and bootstrap a production host that self-heals with autoheal.
version: 4.0.0
author: linksawakening
license: MIT
metadata:
  tags: [devops, docker, docker-compose, gitops, self-hosting, homelab, deployment]
---

# docker-git-deploy-skill

Agent-side skill for [docker-git-deploy](https://github.com/linksawakening/docker-git-deploy).
Use it when a user wants pull-based GitOps deployment for Docker Compose
services on a homelab or production host.

## What docker-git-deploy is

A lightweight pull-based GitOps tool for a single host. You (the agent) edit a
**deployment repo** — a pure-config Git repo the user owns. The production host
runs a systemd timer that pulls that repo and reconciles the Docker Compose
stack. You never need SSH or Docker access to the host after the one-line
bootstrap.

You work with two things:

- **The framework** — this skill's bundled tooling. Run
  `scripts/init-deployment.sh` to scaffold a deployment repo,
  `scripts/validate-repo-structure.sh` to check it, and `scripts/install.sh` to
  bootstrap the host once. You invoke it; you don't edit it.
- **The deployment repo** — what you create and keep editing on the user's
  behalf. It is **pure config**: `compose.yaml`, `.env.example`, and
  `services/`. Never put scripts, systemd units, or a real `.env` in it.

## When to use this skill

- User wants to deploy Docker services via GitOps / pull-based deployment.
- User mentions `docker-git-deploy`.
- User wants to add/update/remove a service on a docker-git-deploy host.
- User reports the production host is not deploying changes.

## Install the skill

```bash
npx skills add https://github.com/linksawakening/docker-git-deploy --skill docker-git-deploy-skill -a <your-agent> -g -y --copy
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

## The deployment repo you create

Everything you generate and edit for the user lives here — pure config, nothing
executable:

```text
<repo>/                      # the user's deployment repo (pure config)
├── compose.yaml             # index: one `include:` line per service
├── .env.example             # every variable the services read (placeholders only)
├── .gitignore               # must ignore .env
├── README.md                # host-specific bootstrap command
└── services/
    └── <name>/compose.yaml  # one directory per service
```

The framework's own tooling — the CLI, systemd unit templates, and the starter
template you scaffold from — lives in this skill under `scripts/` and `assets/`.
You invoke it but never edit it, and none of it is copied into the deployment
repo.

## Agent adoption flow

### 1. Explain prerequisites
Target host needs: Linux + systemd, Docker Engine running, Docker Compose plugin
**v2.1.1+** (the deploy uses `up --wait`), git, curl, and outbound HTTPS to the
git host (any git remote — GitHub, GitLab, Bitbucket, self-hosted). The agent
cannot install these; point the user to `references/prerequisites.md`.

### 2. Interview the user

| Question | Default | Used for |
|----------|---------|----------|
| Production host name? | none | docs / repo name |
| Deployment repo name? | `<host>-deploy` | private repo name |
| Git host + org/user? | user's own | repo URLs (GitHub, GitLab, Bitbucket, ...) |
| Deployment directory on host? | `/opt/<repo>` | clone target |
| Deploy user? | `docker-git-deploy` (unprivileged) | systemd `User=` |
| Poll interval? | `5min` | systemd timer |
| Initial services? | autoheal (from starter) | service definitions |

### 3. Generate the deployment repo

```bash
# Point FRAMEWORK at wherever your agent installed this skill.
FRAMEWORK=<skill-install-dir>/docker-git-deploy-skill
"$FRAMEWORK/scripts/init-deployment.sh" \
  --target-dir ~/my-host-deploy \
  --repo-name my-host-deploy \
  --host-name my-host \
  --org my-org
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
# Any git remote works — GitHub, GitLab, Bitbucket, or self-hosted:
git remote add origin <your-deployment-repo-git-url>
git push -u origin main
```

### 7. Bootstrap the production host (run as root)
```bash
curl -fsSL https://raw.githubusercontent.com/linksawakening/docker-git-deploy/main/docker-git-deploy-skill/scripts/install.sh | \
  bash -s -- \
    --deployment-repo <your-deployment-repo-git-url> \
    --deployment-dir /opt/<repo> \
    --user docker-git-deploy \
    --interval 5min
```
`--deployment-repo` accepts any git URL — HTTPS
(`https://<host>/<org>/<repo>.git`) or SSH (`git@<host>:<org>/<repo>.git`) on
GitHub, GitLab, Bitbucket, or self-hosted. The framework installer is fetched
from GitHub; clone it and run `install.sh` locally, or point `--framework-repo`
at a mirror, if you prefer. For a privileged deploy, use `--user root`. Then the
user creates `.env`:
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
- Forgetting to create `.env` on the host — the deploy is skipped until it exists.
- Putting a real `.env`, scripts, or systemd units in the deployment repo — it
  must stay pure config. Make sure `.gitignore` ignores `.env`.
- Referencing a variable in a compose file without adding it to `.env.example`.
- Adding a service under `services/` but forgetting the `include:` line in
  `compose.yaml` — it will not deploy.
- Editing config directly on the host — the next pull runs `git reset --hard` and
  overwrites it. Always change the repo, never the host.
- autoheal not restarting a container: it needs **both** the `autoheal=true` label
  and a `healthcheck:`.
- Using legacy `docker-compose` instead of the `docker compose` plugin.
- Running the bootstrap install command without root.

## References
- `references/prerequisites.md` — host requirements
- `references/security-model.md` — pull model, credential scopes, docker.sock caveat
- `references/design-constraints.md` — why deployment repos stay pure config
- `references/troubleshooting.md` — failure modes, `--wait`/rollback, CI iptables
- `scripts/validate-repo-structure.sh` — verify a deployment repo is pure config
