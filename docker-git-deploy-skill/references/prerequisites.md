# docker-git-deploy — Target Host Prerequisites

Before bootstrapping a host with `docker-git-deploy-skill/scripts/install.sh`,
the following must already be in place. The agent cannot install these on the
production host — they are the host administrator's responsibility.

## Required

### 1. Linux with systemd
`install.sh` creates a systemd service and timer.

### 2. Docker Engine (daemon running)
```bash
sudo systemctl status docker
```

### 3. Docker Compose plugin v2.1.1+
The deploy uses `docker compose up --wait`, which needs a reasonably recent v2
plugin (not the legacy `docker-compose` binary).
```bash
docker compose version
```

### 4. git
```bash
git --version
```

### 5. curl
```bash
curl --version
```

### 6. Outbound HTTPS to your git host
The host must be able to fetch the deployment repo from your git host over HTTPS
(or SSH with a deploy key). Any git remote works — GitHub, GitLab, Bitbucket, or
self-hosted. No inbound ports are required.
```bash
curl -I https://<your-git-host>
```

## How install.sh handles the deployment user

By default `install.sh` runs the deploy as an unprivileged system user
(`docker-git-deploy`), which it creates and adds to the `docker` group. You do
not need to create it yourself. To run privileged instead, pass `--user root`.

```bash
curl -fsSL https://raw.githubusercontent.com/linksawakening/docker-git-deploy/main/docker-git-deploy-skill/scripts/install.sh | \
  bash -s -- \
    --deployment-repo <your-deployment-repo-git-url> \
    --deployment-dir /opt/<host>-deploy \
    --user docker-git-deploy \
    --interval 5min
```

## Recommended

### Read-only repository access
Use a **read-only deploy key** (SSH) on your git host, or, for HTTPS, a token
scoped to read-only on the deployment repo only (e.g. a GitHub fine-grained PAT
with `contents:read`, a GitLab deploy token, or a Bitbucket app password).

### Secrets stay off Git
Keep real values out of the repo. Create `<deployment-dir>/.env` on the host
after cloning (from `.env.example`), or source it from a secrets manager. The
deploy will not run until `.env` exists.

## Verification checklist

- [ ] `docker compose version` returns v2.1.1 or newer
- [ ] Docker daemon is running
- [ ] `git clone <repo-url>` succeeds from the host
- [ ] `.env` created from `.env.example` with real values
