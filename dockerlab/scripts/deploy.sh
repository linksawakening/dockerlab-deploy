#!/bin/bash
set -euo pipefail

# deploy.sh — production deploy hook called by docker-git-deploy CLI or directly.
# Reads /etc/docker-git-deploy/config for deployment directory.

CONFIG_FILE="/etc/docker-git-deploy/config"

log() {
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"
}

fail() {
    log "ERROR: $*"
    exit 1
}

[[ -f "$CONFIG_FILE" ]] || fail "Not installed. Run install.sh first."
# shellcheck source=/dev/null
source "$CONFIG_FILE"

[[ -d "$DEPLOYMENT_DIR" ]] || fail "Deployment directory $DEPLOYMENT_DIR does not exist"

cd "$DEPLOYMENT_DIR"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    fail "$DEPLOYMENT_DIR is not a git repository"
fi

log "Fetching origin..."
git fetch origin

CURRENT_HEAD="$(git rev-parse HEAD)"
REMOTE_HEAD="$(git rev-parse origin/main)"

if [[ "$CURRENT_HEAD" == "$REMOTE_HEAD" && "${1:-}" != "--force" ]]; then
    log "No changes on origin/main. Current: $CURRENT_HEAD"
    exit 0
fi

log "New commit detected: $CURRENT_HEAD -> $REMOTE_HEAD"
git reset --hard "$REMOTE_HEAD"

log "Validating compose configuration..."
if ! docker compose config >/dev/null 2>&1; then
    fail "docker compose config failed. Reverting is not automatic."
fi

log "Pulling images..."
docker compose pull

log "Applying stack..."
docker compose up -d --remove-orphans

if [[ -x "$DEPLOYMENT_DIR/scripts/health-check.sh" ]]; then
    log "Running health checks..."
    if ! "$DEPLOYMENT_DIR/scripts/health-check.sh"; then
        fail "Health check failed. Review: docker compose logs"
    fi
else
    log "No health-check.sh found; skipping."
fi

log "Deploy complete. Active commit: $REMOTE_HEAD"
