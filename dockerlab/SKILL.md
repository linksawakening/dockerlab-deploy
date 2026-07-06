name: docker-git-deploy
description: Pull-based GitOps deployment of Docker Compose services. The framework repo is installed once on the production host; the deployment repo is pure configuration.
version: 2.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [devops, docker, docker-compose, gitops, self-hosting, homelab, deployment]
---

# Docker Git Deploy

Deploy Docker Compose services from a Git repository using a **pull-based GitOps** model.

This repository is **both**:

1. A **framework/tool** under `docker-git-deploy/` — install once per production host.
2. A **canonical deployment example** at the top level — real compose configuration that installs the framework and points to itself.

For a separate deployment repo, copy the top-level files (or use the generator in `docker-git-deploy/scripts/init-deployment.sh`) and point the framework at that repo.

> **For agents:** see `docker-git-deploy/templates/docker-git-deploy-skill/SKILL.md` for the agent-side adoption guide.

## Core architecture

```text
┌─────────────────┐   push   ┌─────────────────────┐   pull   ┌─────────────────────┐
│  Agent / user   │─────────▶│  deployment repo    │◀─────────│  production host    │
│  edits config   │          │  (compose, env,     │          │  docker-git-deploy   │
│  only           │          │   services)         │          │  timer runs deploy  │
└─────────────────┘          └─────────────────────┘          └─────────────────────┘
        │                                                            │
        └───────────── framework docker-git-deploy/ ─────────────────────────┘
             (install.sh, docker-git-deploy CLI, deploy.sh, systemd units, skill)
```

## Layout

```
docker-git-deploy/                    # GitHub repo = canonical deployment example
├── compose.yaml                     # example deployment services
├── .env.example
├── .gitignore
├── services/searxng/
├── README.md
├── .github/workflows/
│   ├── install-test.yaml           # CI: test install.sh against this repo
│   └── validate.yaml               # CI: validate compose
└── docker-git-deploy/                       # framework + agent skill
    ├── SKILL.md
    ├── scripts/
    │   ├── install.sh             # one-command production install
    │   ├── docker-git-deploy              # CLI entrypoint
    │   ├── deploy.sh              # deploy hook (used by systemd)
    │   └── init-deployment.sh     # generator for separate deployment repos
    ├── templates/
    │   ├── docker-git-deploy-starter/   # minimal separate-deployment starter
    │   ├── docker-git-deploy-skill/             # agent adoption guide
    │   ├── services/                    # service catalog
    │   └── systemd/                    # systemd units
    └── references/
        ├── prerequisites.md
        ├── security-model.md
        └── troubleshooting.md
```

## Production install (one command)

Install this very repo onto a host as both framework and deployment:

```bash
curl -fsSL https://raw.githubusercontent.com/linksawakening/docker-git-deploy/main/docker-git-deploy/scripts/install.sh | \
  bash -s -- \
    --deployment-repo https://github.com/linksawakening/docker-git-deploy.git \
    --deployment-dir /opt/docker-git-deploy \
    --user docker-git-deploy \
    --interval 5min
```

What it does:

1. Checks prerequisites (Docker, git, curl, systemd)
2. Creates deployment user if missing
3. Clones framework to `/opt/docker-git-deploy`
4. Clones deployment repo to specified directory
5. Writes `/etc/docker-git-deploy/config`
6. Installs `docker-git-deploy` CLI to `/usr/local/bin/docker-git-deploy`
7. Writes systemd service and timer
8. Enables and starts the timer

## What the timer does

Every interval, systemd runs `docker-git-deploy deploy` which:

1. Reads `/etc/docker-git-deploy/config`
2. Pulls the deployment repo
3. Validates with `docker compose config`
4. Pulls images
5. Runs `docker compose up -d --remove-orphans`

## CLI commands

After install, the `docker-git-deploy` command is available on the production host:

```bash
docker-git-deploy deploy          # pull and apply
docker-git-deploy deploy --force  # deploy even if no changes
docker-git-deploy validate        # run docker compose config
docker-git-deploy test            # smoke test (tears down by default)
docker-git-deploy test --keep     # smoke test and leave running
docker-git-deploy status          # docker compose ps
docker-git-deploy logs [service]  # docker compose logs
```

## Deployment repo layout (separate)

```
my-host-deploy/
├── README.md
├── .env.example
├── .env                       # real values, ignored
├── .gitignore
├── compose.yaml
└── services/
    └── searxng/
        └── compose.yaml
```

No deploy logic, no systemd files, no helper scripts. Pure config.

## Agent adoption flow

1. **Install the agent skill:**

   ```bash
   npx skills add https://github.com/linksawakening/docker-git-deploy --skill docker-git-deploy-skill -a hermes-agent -g -y --copy
   ```

2. **Follow `docker-git-deploy/templates/docker-git-deploy-skill/SKILL.md`** to interview the user, generate the deployment repo, test locally, and provide production install commands.

## Environment handling

| File | Where | Purpose |
|------|-------|---------|
| `.env.example` | Deployment repo | Template of required variables |
| `.env` | Production host | Real values, ignored by Git |
| `compose.yaml` | Deployment repo | Uses `${VAR:-default}` for safe defaults |

## Security considerations

- The deployment repo only needs read access from the production host.
- Real secrets live in `.env` on the production host, not in Git.
- Use a read-only deploy key or fine-grained PAT.
- Pin upstream images by digest when reproducibility matters.
- Enable branch protection on `main` with required reviews.

## References

- `docker-git-deploy/references/prerequisites.md` — target host requirements
- `docker-git-deploy/references/security-model.md` — keys, scopes, threat model
- `docker-git-deploy/references/troubleshooting.md` — common failure modes
- `docker-git-deploy/templates/docker-git-deploy-skill/SKILL.md` — agent adoption guide
