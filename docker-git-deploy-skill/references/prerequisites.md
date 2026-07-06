# Docker Git Deploy — Target Host Prerequisites

Before bootstrapping a target host with `scripts/install-host.sh`, ensure the following base requirements are met. The agent can help guide preparation, but these are system-level responsibilities of the host administrator.

## Required

### 1. Linux host with systemd

The install script creates a systemd service and timer. Your host must use systemd.

### 2. Docker Engine

Docker must be installed and the daemon must be running.

```bash
sudo systemctl status docker
```

The deployment user must be able to run `docker` commands. Either:

- Run the timer as `root`, or
- Add the service user to the `docker` group:

```bash
sudo usermod -aG docker docker-git-deploy
```

### 3. Docker Compose plugin

The `docker compose` command (v2 plugin) must be available, not the legacy `docker-compose` binary.

```bash
docker compose version
```

### 4. git

```bash
git --version
```

### 5. curl

Used by health checks and validation.

```bash
curl --version
```

### 6. Outbound HTTPS to GitHub

The host must be able to clone or fetch from GitHub over HTTPS (or SSH if using a deploy key).

```bash
curl -I https://github.com
```

### 7. Deployment directory

Pick a persistent directory such as `/opt/docker-git-deploy` and ensure the deployment user can write to it.

```bash
sudo mkdir -p /opt/docker-git-deploy
sudo chown docker-git-deploy:docker-git-deploy /opt/docker-git-deploy
```

## Recommended

### Dedicated deployment user

Create an unprivileged user for the deployment timer:

```bash
sudo useradd -r -s /usr/sbin/nologin -m -d /opt/docker-git-deploy docker-git-deploy
```

When running `install-host.sh`, set:

```bash
DOCKER_DEPLOY_USER=docker-git-deploy DOCKER_DEPLOY_REPO_DIR=/opt/docker-git-deploy ./scripts/install-host.sh
```

### Read-only repository access

Use a GitHub deploy key with **read-only** access. If using HTTPS, create a fine-grained PAT with only `contents:read` for this repo.

### Separate secrets management

Keep real `.env` values outside the repo. Options:

- Manually create `/opt/docker-git-deploy/.env` after cloning.
- Use a separate private secrets repo and symlink `.env`.
- Use a secrets manager such as Bitwarden or HashiCorp Vault if available.

## Verification checklist

- [ ] `docker compose version` returns v2.x
- [ ] `docker ps` runs without `sudo` (or timer will run as root)
- [ ] `git clone <repo-url>` succeeds from the host
- [ ] Deployment directory exists and is writable by the chosen user
- [ ] `.env` file created from `.env.example` with real values
