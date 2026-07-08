#!/bin/bash
set -euo pipefail

# install.sh
# One-command install of docker-git-deploy on a production host.
#
# Usage (remote):
#   curl -fsSL https://.../docker-git-deploy-skill/scripts/install.sh | bash -s -- [options]
# Usage (local clone):
#   sudo ./docker-git-deploy-skill/scripts/install.sh [options]

FRAMEWORK_REPO_DEFAULT="https://github.com/linksawakening/docker-git-deploy.git"
FRAMEWORK_REPO="${FRAMEWORK_REPO:-$FRAMEWORK_REPO_DEFAULT}"
# Where the framework REPO is cloned on the host. The skill (and therefore the
# tooling) lives in the docker-git-deploy-skill/ subdirectory of that clone.
FRAMEWORK_SRC="${FRAMEWORK_SRC:-/opt/docker-git-deploy}"
SKILL_SUBDIR="docker-git-deploy-skill"
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
  --deployment-repo <url>    Git URL of the deployment repo (pure config)
  --deployment-dir <dir>     Directory to clone the deployment repo into

Optional:
  --framework-repo <url>     Git URL of the framework repo
                             (default: $FRAMEWORK_REPO_DEFAULT)
  --framework-dir <dir>      Directory to clone the framework repo into
                             (default: $FRAMEWORK_SRC)
  --user <name>              User the timer runs as (default: docker-git-deploy;
                             pass 'root' to run privileged)
  --interval <duration>      Poll interval, systemd format (default: 5min)
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --framework-repo) FRAMEWORK_REPO="$2"; shift 2 ;;
        --framework-dir) FRAMEWORK_SRC="$2"; shift 2 ;;
        --deployment-repo) DEPLOYMENT_REPO="$2"; shift 2 ;;
        --deployment-dir) DEPLOYMENT_DIR="$2"; shift 2 ;;
        --user) DEPLOY_USER="$2"; shift 2 ;;
        --interval) POLL_INTERVAL="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) fail "Unknown argument: $1" ;;
    esac
done

[[ -n "$DEPLOYMENT_REPO" ]] || { usage; fail "--deployment-repo is required"; }
[[ -n "$DEPLOYMENT_DIR" ]] || { usage; fail "--deployment-dir is required"; }
[[ "$EUID" -eq 0 ]] || fail "This script must run as root"

log "Checking prerequisites..."
command -v systemctl >/dev/null 2>&1 || fail "systemd is required"
command -v docker >/dev/null 2>&1 || fail "Docker is required"
docker compose version >/dev/null 2>&1 || fail "Docker Compose plugin is required"
command -v git >/dev/null 2>&1 || fail "git is required"
command -v curl >/dev/null 2>&1 || fail "curl is required"

# --- Resolve the framework (skill) directory ---------------------------------
# Prefer a local clone when install.sh is run from one (used by CI and local
# development); otherwise clone the framework repo.
FRAMEWORK_DIR=""
SCRIPT_PATH="${BASH_SOURCE[0]}"
if [[ -f "$SCRIPT_PATH" ]]; then
    CANDIDATE="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"  # .../docker-git-deploy-skill
    if [[ -f "$CANDIDATE/scripts/docker-git-deploy" ]]; then
        FRAMEWORK_DIR="$CANDIDATE"
        log "Using local framework at $FRAMEWORK_DIR"
    fi
fi

if [[ -z "$FRAMEWORK_DIR" ]]; then
    if [[ -d "$FRAMEWORK_SRC/.git" ]]; then
        log "Framework repo already present; pulling latest..."
        git -C "$FRAMEWORK_SRC" pull --ff-only
    else
        log "Cloning framework repo into $FRAMEWORK_SRC..."
        rm -rf "$FRAMEWORK_SRC"
        git clone --depth 1 "$FRAMEWORK_REPO" "$FRAMEWORK_SRC"
    fi
    FRAMEWORK_DIR="$FRAMEWORK_SRC/$SKILL_SUBDIR"
fi

[[ -f "$FRAMEWORK_DIR/scripts/docker-git-deploy" ]] || \
    fail "Framework CLI not found at $FRAMEWORK_DIR/scripts/docker-git-deploy"

# --- Deployment user ---------------------------------------------------------
if [[ "$DEPLOY_USER" != "root" ]]; then
    if ! id -u "$DEPLOY_USER" >/dev/null 2>&1; then
        log "Creating system user $DEPLOY_USER..."
        useradd -r -s /usr/sbin/nologin -m -d "/var/lib/$DEPLOY_USER" "$DEPLOY_USER" || \
            useradd -r -s /usr/sbin/nologin "$DEPLOY_USER"
    fi
    # The user must be able to talk to the Docker daemon.
    if getent group docker >/dev/null 2>&1; then
        usermod -aG docker "$DEPLOY_USER"
    else
        log "WARNING: no 'docker' group found; $DEPLOY_USER may not reach the Docker socket."
    fi
fi

# --- Clone / update the deployment repo --------------------------------------
log "Preparing deployment directory $DEPLOYMENT_DIR..."
mkdir -p "$DEPLOYMENT_DIR"
if [[ -d "$DEPLOYMENT_DIR/.git" ]]; then
    log "Deployment repo already present; pulling latest..."
    git -C "$DEPLOYMENT_DIR" pull --ff-only
else
    log "Cloning deployment repo..."
    rm -rf "$DEPLOYMENT_DIR"
    git clone "$DEPLOYMENT_REPO" "$DEPLOYMENT_DIR"
fi
chown -R "$DEPLOY_USER:$DEPLOY_USER" "$DEPLOYMENT_DIR"

# --- Config ------------------------------------------------------------------
mkdir -p /etc/docker-git-deploy
cat > /etc/docker-git-deploy/config <<EOF
FRAMEWORK_DIR=$FRAMEWORK_DIR
DEPLOYMENT_DIR=$DEPLOYMENT_DIR
DEPLOYMENT_REPO=$DEPLOYMENT_REPO
DEPLOY_USER=$DEPLOY_USER
POLL_INTERVAL=$POLL_INTERVAL
EOF

install -m 755 "$FRAMEWORK_DIR/scripts/docker-git-deploy" /usr/local/bin/docker-git-deploy

# --- systemd units (rendered from templates) ---------------------------------
log "Installing systemd units..."
render_unit() {
    sed -e "s|@@DEPLOY_USER@@|$DEPLOY_USER|g" \
        -e "s|@@DEPLOYMENT_DIR@@|$DEPLOYMENT_DIR|g" \
        -e "s|@@POLL_INTERVAL@@|$POLL_INTERVAL|g" \
        "$1" > "$2"
}
render_unit "$FRAMEWORK_DIR/assets/systemd/docker-git-deploy.service.in" \
    /etc/systemd/system/docker-git-deploy.service
render_unit "$FRAMEWORK_DIR/assets/systemd/docker-git-deploy.timer.in" \
    /etc/systemd/system/docker-git-deploy.timer

systemctl daemon-reload
systemctl enable --now docker-git-deploy.timer

# --- Initial deploy (only if .env is already present) ------------------------
if [[ -f "$DEPLOYMENT_DIR/.env" ]]; then
    log "Found .env; running initial deploy..."
    /usr/local/bin/docker-git-deploy deploy --force || \
        log "WARNING: initial deploy failed; check 'docker-git-deploy logs'."
else
    log "No .env yet; skipping initial deploy. The timer will deploy once .env exists."
fi

log "Install complete."
log "  Framework: $FRAMEWORK_DIR"
log "  Deployment repo: $DEPLOYMENT_DIR"
log "  Runs as user: $DEPLOY_USER   Interval: $POLL_INTERVAL"
log "  Config: /etc/docker-git-deploy/config"
log ""
log "Next steps:"
log "  1. Create $DEPLOYMENT_DIR/.env from $DEPLOYMENT_DIR/.env.example"
log "  2. Verify timer: systemctl list-timers docker-git-deploy.timer"
log "  3. Watch logs:   journalctl -u docker-git-deploy.service -f"
