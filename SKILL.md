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

The **framework repo** (`docker-git-deploy`) is the tool. It is installed once on each production host. The **deployment repo** is pure configuration: just `compose.yaml`, `.env`, and service definitions.

> **For agents:** see `templates/docker-git-deploy-skill/SKILL.md` for the agent-side adoption guide.

## Core architecture

```text
┌─────────────────┐   push   ┌─────────────────────┐   pull   ┌─────────────────────┐
│  Agent / user   │─────────▶│  deployment repo    │◀─────────│  production host    │
│  edits config   │          │  (compose, env,     │          │  docker-git-deploy   │
│  only           │          │   services)         │          │  timer runs deploy  │
└─────────────────┘          └─────────────────────┘          └─────────────────────┘
        │                                                            │
        └────────────────── framework repo ──────────────────────────┘
                    (deploy.sh, install.sh, systemd units, agent skill)
```

## Repos

| Repo | Contains | Where it runs |
|------|----------|---------------|
| `docker-git-deploy` | Tooling, install script, deploy script, systemd units, docs, agent skill | Installed on production host; used by agent |
| `docker-git-deploy-example-deploy` | `compose.yaml`, `.env.example`, `services/` | Cloned to production host by the tool |

## Production install (one command)

```bash
curl -fsSL https://raw.githubusercontent.com/linksawakening/docker-git-deploy/main/scripts/install.sh | \
  bash -s -- \
    --deployment-repo https://github.com/linksawakening/docker-git-deploy-example-deploy.git \
    --deployment-dir /opt/docker-git-deploy-example-deploy \
    --user docker-git-deploy \
    --interval 5min
```

What it does:

1. Checks prerequisites (Docker, git, curl, systemd)
2. Creates deployment user if missing
3. Clones deployment repo to specified directory
4. Writes `/etc/docker-git-deploy/config`
5. Writes systemd service and timer
6. Enables and starts the timer

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

## Deployment repo layout

```
docker-git-deploy-example-deploy/
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

## Framework repo layout

```
docker-git-deploy/
├── SKILL.md
├── scripts/
│   ├── install.sh             # one-command production install
│   ├── docker-git-deploy              # CLI entrypoint
│   ├── deploy.sh              # deploy hook (used by systemd)
│   └── init-deployment.sh     # framework's own generator
├── templates/
│   ├── docker-git-deploy-starter/   # minimal deployment repo
│   ├── docker-git-deploy-skill/             # agent adoption guide
│   ├── services/                    # service catalog
│   └── systemd/                    # systemd units
└── references/
```

## Agent adoption flow

1. **Install the agent skill:**

   ```bash
   npx skills add https://github.com/linksawakening/docker-git-deploy --skill docker-git-deploy-skill -a hermes-agent -g -y --copy
   ```

2. **Follow `templates/docker-git-deploy-skill/SKILL.md`** to interview the user, generate the deployment repo, test locally, and provide production install commands.

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

- `references/prerequisites.md` — target host requirements
- `references/security-model.md` — keys, scopes, threat model
- `references/troubleshooting.md` — common failure modes
- `templates/docker-git-deploy-skill/SKILL.md` — agent adoption guide
