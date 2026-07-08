# docker-git-deploy deployment repo

Pure-config GitOps deployment. A production host polls this repository and
applies `compose.yaml` automatically on every change — no SSH or push access to
the host is required.

> This is the starter that ships with the skill. `init-deployment.sh` copies it
> and rewrites this README with the bootstrap command for your specific host.

## What's here

```text
├── compose.yaml                 # index: includes one file per service
├── .env.example                 # required variables (copy to .env on the host)
├── .gitignore                   # keeps .env and data/ out of git
└── services/
    └── autoheal/compose.yaml     # restarts unhealthy containers
```

This repo is **pure config**. It must never contain install/deploy scripts,
systemd units, or other tooling — all of that lives in the framework
(`docker-git-deploy-skill/`).

## The autoheal service

[autoheal](https://github.com/willfarrell/docker-autoheal) watches containers
and restarts any that report `unhealthy`. A container is watched only if it
**both** carries the watch label and defines a healthcheck:

```yaml
services:
  my-app:
    image: my/app
    labels:
      - autoheal=true          # matches AUTOHEAL_CONTAINER_LABEL
    healthcheck:
      test: ["CMD", "curl", "-fsS", "http://localhost:8080/health"]
      interval: 30s
      timeout: 5s
      retries: 3
```

## Add a service

1. Create `services/<name>/compose.yaml`.
2. Add its variables to `.env.example`.
3. Add `- services/<name>/compose.yaml` to the `include:` list in `compose.yaml`.
4. Validate, commit, and push. The host applies it on the next poll.

## Bootstrap the host

Run as root on the production host (the generated README from
`init-deployment.sh` fills in your URLs):

```bash
# --deployment-repo takes any git URL (GitHub, GitLab, Bitbucket, self-hosted).
curl -fsSL https://raw.githubusercontent.com/linksawakening/docker-git-deploy/main/docker-git-deploy-skill/scripts/install.sh | \
  bash -s -- \
    --deployment-repo <this-repo-git-url> \
    --deployment-dir /opt/<host>-deploy \
    --interval 5min
```

Then create the `.env`:

```bash
sudo cp /opt/<host>-deploy/.env.example /opt/<host>-deploy/.env
sudo nano /opt/<host>-deploy/.env
```
