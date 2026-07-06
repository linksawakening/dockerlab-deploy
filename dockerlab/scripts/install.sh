#!/bin/bash
set -euo pipefail

# install.sh
# One-command install of docker-git-deploy on a production host.
# Usage:
#   curl -fsSL https://.../docker-git-deploy/scripts/install.sh | bash -s -- [options]
# Or locally:
#   sudo ./docker-git-deploy/scripts/install.sh [options]

FRAMEWORK_REPO_DEFAULT="https://github.com/linksawakening/docker-git-deploy.git"
FRAMEWORK_REPO="${FRAMEWORK_REPO:-$FRAMEWORK_REPO_DEFAULT}"
FRAMEWORK_DIR="${FRAMEWORK_DIR:-/opt/docker-git-deploy}"
DEPLOYMENT_REPO="${DEPLOYMENT_REPO:-}"
DEPLOYMENT_DIR="${DEPLOYMENT_DIR:-}"
DEPLOY_USER="${DEPLOY_USER:-docker-git-deploy}"
POLL_INTERVAL="${POLL_INTERVAL:-5min}"

log() { echo "[docker-git-deploy] $*"; }
fail() { log "ERROR: $*"; exit 1; }

usage() {
    cat <<EOF
Usage: install.sh --deployment-repo <url> --deployment-dir <dir> [options]

Required:
  --deployment-repo <url>    Git URL of the deployment repo
  --deployment-dir <dir>     Directory to clone deployment repo on this host

Optional:
  --framework-repo <url>     Git URL of the framework repo
                             (default: $FRAMEWORK_REPO_DEFAULT)
  --framework-dir <dir>      Directory to install framework
                             (default: $FRAMEWORK_DIR)
  --user <name>              User to run the timer as (default: docker-git-deploy)
  --interval <duration>      Poll interval (default: 5min)
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --framework-repo) FRAMEWORK_REPO="$2"; shift 2 ;;
        --framework-dir) FRAMEWORK_DIR="$2"; shift 2 ;;
        --deployment-repo) DEPLOYMENT_REPO="$2"; shift 2 ;;
        --deployment-dir) DEPLOYMENT_DIR="$2"; shift 2 ;;
        --user) DEPLOY_USER="$2"; shift 2 ;;
        --interval) POLL_INTERVAL="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) fail "Unknown argument: $1" ;;
    esac
done

[[ -n "$DEPLOYMENT_REPO" ]] || fail "--deployment-repo is required"
[[ -n "$DEPLOYMENT_DIR" ]] || fail "--deployment-dir is required"
[[ "$EUID" -eq 0 ]] || fail "This script must run as root"

log "Checking prerequisites..."
command -v systemctl >/dev/null 2>&1 || fail "systemd is required"
command -v docker >/dev/null 2>&1 || fail "Docker is required"
docker compose version >/dev/null 2>&1 || fail "Docker Compose plugin is required"
command -v git >/dev/null 2>&1 || fail "git is required"
command -v curl >/dev/null 2>&1 || fail "curl is required"

if ! id -u "$DEPLOY_USER" >/dev/null 2>&1; then
    log "Creating user $DEPLOY_USER..."
    useradd -r -s /usr/sbin/nologin -m -d "/var/lib/$DEPLOY_USER" "$DEPLOY_USER" || \
        useradd -r -s /usr/sbin/nologin "$DEPLOY_USER"
fi

if [[ "$DEPLOY_USER" != "root" ]]; then
    usermod -aG docker "$DEPLOY_USER" || true
fi

# If running from a local clone of docker-git-deploy, prefer the local framework
# source. This is used in CI and for local development.
SCRIPT_PATH="${BASH_SOURCE[0]}"
if [[ -f "$SCRIPT_PATH" ]]; then
    LOCAL_FRAMEWORK_DIR="$(cd "$(dirname "$SCRIPT_PATH")/../.." && pwd)/docker-git-deploy"
    if [[ -d "$LOCAL_FRAMEWORK_DIR" && -f "$LOCAL_FRAMEWORK_DIR/scripts/docker-git-deploy" ]]; then
        FRAMEWORK_DIR="$LOCAL_FRAMEWORK_DIR"
        FRAMEWORK_REPO="local"
        log "Using local framework at $FRAMEWORK_DIR"
    fi
fi

if [[ "$FRAMEWORK_REPO" != "local" ]]; then
    if [[ -d "$FRAMEWORK_DIR/.git" ]]; then
        log "Framework repo already exists; pulling latest..."
        cd "$FRAMEWORK_DIR"
        git pull
    else
        log "Cloning framework repo..."
        rm -rf "$FRAMEWORK_DIR"
        git clone "$FRAMEWORK_REPO" "$FRAMEWORK_DIR"
    fi
fi

[[ -d "$FRAMEWORK_DIR" ]] || fail "Framework directory $FRAMEWORK_DIR does not exist"
[[ -f "$FRAMEWORK_DIR/scripts/docker-git-deploy" ]] || fail "Framework CLI not found at $FRAMEWORK_DIR/scripts/docker-git-deploy"

log "Creating deployment directory $DEPLOYMENT_DIR..."
mkdir -p "$DEPLOYMENT_DIR"

if [[ -d "$DEPLOYMENT_DIR/.git" ]]; then
    log "Deployment repo already exists; pulling latest..."
    cd "$DEPLOYMENT_DIR"
    git pull
else
    log "Cloning deployment repo..."
    rm -rf "$DEPLOYMENT_DIR"
    git clone "$DEPLOYMENT_REPO" "$DEPLOYMENT_DIR"
fi

chown -R "$DEPLOY_USER:$DEPLOY_USER" "$DEPLOYMENT_DIR"

mkdir -p /etc/docker-git-deploy
cat > /etc/docker-git-deploy/config <<EOF
FRAMEWORK_DIR=$FRAMEWORK_DIR
DEPLOYMENT_DIR=$DEPLOYMENT_DIR
DEPLOYMENT_REPO=$DEPLOYMENT_REPO
DEPLOY_USER=$DEPLOY_USER
POLL_INTERVAL=$POLL_INTERVAL
EOF

install -m 755 "$FRAMEWORK_DIR/scripts/docker-git-deploy" /usr/local/bin/docker-git-deploy

log "Installing systemd units..."
mkdir -p /etc/systemd/system
cp "$FRAMEWORK_DIR/templates/systemd/docker-git-deploy.service" /etc/systemd/system/
cp "$FRAMEWORK_DIR/templates/systemd/docker-git-deploy.timer" /etc/systemd/system/

systemctl daemon-reload
systemctl enable --now docker-git-deploy.timer

log "Install complete."
log "Framework: $FRAMEWORK_DIR"
log "Deployment repo: $DEPLOYMENT_DIR"
log "Config: /etc/docker-git-deploy/config"
log ""
log "Next steps:"
log "  1. Create $DEPLOYMENT_DIR/.env from $DEPLOYMENT_DIR/.env.example"
log "  2. Verify timer: systemctl list-timers docker-git-deploy.timer"
log "  3. Watch logs: journalctl -u docker-git-deploy.service -f"
