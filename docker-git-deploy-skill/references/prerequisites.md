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

### 6. Outbound HTTPS to GitHub
The host must be able to fetch from GitHub over HTTPS (or SSH with a deploy key).
No inbound ports are required.
```bash
curl -I https://github.com
```

## How install.sh handles the deployment user

By default `install.sh` runs the deploy as an unprivileged system user
(`docker-git-deploy`), which it creates and adds to the `docker` group. You do
not need to create it yourself. To run privileged instead, pass `--user root`.

```bash
curl -fsSL https://raw.githubusercontent.com/<org>/docker-git-deploy/main/docker-git-deploy-skill/scripts/install.sh | \
  bash -s -- \
    --deployment-repo https://github.com/<org>/<repo>.git \
    --deployment-dir /opt/<host>-deploy \
    --user docker-git-deploy \
    --interval 5min
```

## Recommended

### Read-only repository access
Use a GitHub **deploy key** with read-only access, or, for HTTPS, a fine-grained
PAT scoped to `contents:read` on the deployment repo only.

### Secrets stay off Git
Keep real values out of the repo. Create `<deployment-dir>/.env` on the host
after cloning (from `.env.example`), or source it from a secrets manager. The
deploy will not run until `.env` exists.

## Verification checklist

- [ ] `docker compose version` returns v2.1.1 or newer
- [ ] Docker daemon is running
- [ ] `git clone <repo-url>` succeeds from the host
- [ ] `.env` created from `.env.example` with real values
