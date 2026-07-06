# docker-git-deploy

This repository is **two things**:

1. A Docker Git deployment example (top-level files).
2. The docker-git-deploy-skill/framework in the `docker-git-deploy-skill/` directory.

The top-level files are a working deployment configuration that the framework installs. The framework itself lives in `docker-git-deploy-skill/`.

## Quick start

Install the framework, pointing it at this repository:

```bash
curl -fsSL https://raw.githubusercontent.com/linksawakening/docker-git-deploy/main/docker-git-deploy-skill/scripts/install.sh | \
  bash -s -- \
    --deployment-repo https://github.com/linksawakening/docker-git-deploy.git \
    --deployment-dir /opt/docker-git-deploy \
    --user docker-git-deploy \
    --interval 5min
```

Then create `/opt/docker-git-deploy/.env` from `.env.example`.

## For agents

The agent skill is `docker-git-deploy-skill/SKILL.md`. Install it with:

```bash
npx skills add https://github.com/linksawakening/docker-git-deploy --skill docker-git-deploy-skill -a hermes-agent -g -y --copy
```

## Structure

```text
├── compose.yaml                    # this deployment's services
├── .env.example                    # required env vars
├── .gitignore
├── services/                        # per-service compose files
│   ├── example-service/
│   └── searxng/
├── docker-git-deploy-skill/          # framework + agent skill
│   ├── SKILL.md
│   ├── scripts/
│   │   ├── install.sh
│   │   ├── docker-git-deploy
│   │   ├── deploy.sh
│   │   └── init-deployment.sh
│   ├── templates/
│   │   ├── docker-git-deploy-starter/
│   │   ├── services/
│   │   └── systemd/
│   └── references/
└── .github/workflows/
    ├── install-test.yaml            # test install.sh against this repo
    └── validate.yaml                # validate compose config
```
