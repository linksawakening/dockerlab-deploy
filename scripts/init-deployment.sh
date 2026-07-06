#!/bin/bash
set -euo pipefail

# init-deployment.sh
# Generate a lightweight deployment repo from the starter.
# Usage: ./scripts/init-deployment.sh

FRAMEWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STARTER_DIR="$FRAMEWORK_DIR/templates/docker-git-deploy-starter"

log() { echo "[docker-git-deploy] $*"; }

if [[ ! -d "$STARTER_DIR" ]]; then
    log "ERROR: starter template not found at $STARTER_DIR"
    exit 1
fi

[[ -z "${TARGET_DIR:-}" ]] && read -rp "Target directory (e.g. ./ribeedocker-deploy): " TARGET_DIR
[[ -z "${REPO_NAME:-}" ]] && read -rp "GitHub repo name (e.g. ribeedocker-deploy): " REPO_NAME
[[ -z "${HOST_NAME:-}" ]] && read -rp "Production host name (e.g. ribeedocker): " HOST_NAME

[[ -z "$TARGET_DIR" ]] && { log "ERROR: TARGET_DIR required"; exit 1; }
[[ -z "$REPO_NAME" ]] && { log "ERROR: REPO_NAME required"; exit 1; }

TARGET_DIR="$(cd "$(dirname "$TARGET_DIR")" && pwd)/$(basename "$TARGET_DIR")"
[[ -e "$TARGET_DIR" ]] && { log "ERROR: $TARGET_DIR already exists"; exit 1; }

cp -r "$STARTER_DIR" "$TARGET_DIR"

BOOTSTRAP="$TARGET_DIR/bootstrap-$HOST_NAME.sh"
cat > "$BOOTSTRAP" <<EOF
#!/bin/bash
# One-time bootstrap for $HOST_NAME.
# Run as root on $HOST_NAME.

set -euo pipefail

# 1. Clone the framework repo (or use curl install)
FRAMEWORK_DIR="/opt/docker-git-deploy"
if [[ ! -d "\$FRAMEWORK_DIR" ]]; then
    git clone https://github.com/YOUR_ORG/docker-git-deploy.git "\$FRAMEWORK_DIR"
fi

# 2. Install docker-git-deploy, pointing at this deployment repo
"\$FRAMEWORK_DIR/scripts/install.sh" \\
    --deployment-repo https://github.com/YOUR_ORG/$REPO_NAME.git \\
    --deployment-dir /opt/$REPO_NAME \\
    --user docker-git-deploy \\
    --interval 5min

# 3. Create real .env
cp /opt/$REPO_NAME/.env.example /opt/$REPO_NAME/.env
nano /opt/$REPO_NAME/.env

# 4. Verify
systemctl list-timers docker-git-deploy.timer
journalctl -u docker-git-deploy.service -f
EOF
chmod +x "$BOOTSTRAP"

cat > "$TARGET_DIR/README.md" <<EOF
# $REPO_NAME

Docker Git deployment configuration for $HOST_NAME.

## Bootstrap

Run on $HOST_NAME as root:

\`\`\`bash
./$BOOTSTRAP
\`\`\`

Or install manually using the docker-git-deploy framework.

## Local validation

\`\`\`bash
./scripts/validate.sh
./scripts/test-local.sh
\`\`\`
EOF

log "Created $TARGET_DIR"
log "Review $BOOTSTRAP, then push to GitHub as $REPO_NAME"
