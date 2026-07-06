#!/bin/bash
set -euo pipefail

# Agent-side helper to generate a docker-git-deploy deployment repo.
# Usage: ./scripts/init-deployment.sh

FRAMEWORK_SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STARTER_DIR="$FRAMEWORK_SKILL_DIR/templates/docker-git-deploy-starter"

log() { echo "[docker-git-deploy-skill] $*"; }
fail() { log "ERROR: $*"; exit 1; }

[[ -d "$STARTER_DIR" ]] || fail "starter template not found at $STARTER_DIR"

[[ -z "${TARGET_DIR:-}" ]] && read -rp "Target directory for deployment repo: " TARGET_DIR
[[ -z "${REPO_NAME:-}" ]] && read -rp "GitHub repo name: " REPO_NAME
[[ -z "${HOST_NAME:-}" ]] && read -rp "Production host name: " HOST_NAME
[[ -z "${ORG:-}" ]] && read -rp "GitHub org/user: " ORG

[[ -z "$TARGET_DIR" ]] && fail "TARGET_DIR is required"
[[ -z "$REPO_NAME" ]] && fail "REPO_NAME is required"
[[ -z "$HOST_NAME" ]] && fail "HOST_NAME is required"
[[ -z "$ORG" ]] && fail "ORG is required"

TARGET_DIR="$(cd "$(dirname "$TARGET_DIR")" && pwd)/$(basename "$TARGET_DIR")"
[[ -e "$TARGET_DIR" ]] && fail "$TARGET_DIR already exists"

cp -r "$STARTER_DIR" "$TARGET_DIR"

# Add bootstrap script
BOOTSTRAP="$TARGET_DIR/bootstrap-$HOST_NAME.sh"
cat > "$BOOTSTRAP" <<EOF
#!/bin/bash
# One-time bootstrap for $HOST_NAME.
# Run as root on $HOST_NAME.

set -euo pipefail

FRAMEWORK_DIR="/opt/docker-git-deploy"
if [[ ! -d "\$FRAMEWORK_DIR" ]]; then
    git clone https://github.com/$ORG/docker-git-deploy.git "\$FRAMEWORK_DIR"
fi

"\$FRAMEWORK_DIR/scripts/install.sh" \\
    --deployment-repo https://github.com/$ORG/$REPO_NAME.git \\
    --deployment-dir /opt/$REPO_NAME \\
    --user docker-git-deploy \\
    --interval 5min

echo "Install complete. Create /opt/$REPO_NAME/.env from .env.example."
EOF
chmod +x "$BOOTSTRAP"

cat > "$TARGET_DIR/README.md" <<EOF
# $REPO_NAME

Docker Git deployment configuration for $HOST_NAME.

## Bootstrap

Run as root on $HOST_NAME:

\`\`\`bash
./bootstrap-$HOST_NAME.sh
\`\`\`

Then create \`.env\` from \`.env.example\`.

## Local validation

\`\`\`bash
./scripts/validate.sh
./scripts/test-local.sh
\`\`\`
EOF

log "Created $TARGET_DIR"
log "Push to GitHub: https://github.com/$ORG/$REPO_NAME"
log "Give bootstrap-$HOST_NAME.sh to the user to run on $HOST_NAME"
