#!/bin/bash
set -euo pipefail

# init-deployment.sh
# Generate a lightweight deployment repo from the starter.
# Usage: ./docker-git-deploy/scripts/init-deployment.sh

FRAMEWORK_SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STARTER_DIR="$FRAMEWORK_SKILL_DIR/docker-git-deploy/templates/docker-git-deploy-starter"

log() { echo "[docker-git-deploy] $*"; }
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

cat > "$TARGET_DIR/README.md" <<EOF
# $REPO_NAME

Docker Git deployment configuration for $HOST_NAME.

## Bootstrap on $HOST_NAME

Run as root:

\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/$ORG/docker-git-deploy/main/docker-git-deploy/scripts/install.sh | \\
  bash -s -- \\
    --deployment-repo https://github.com/$ORG/$REPO_NAME.git \\
    --deployment-dir /opt/$REPO_NAME \\
    --user docker-git-deploy \\
    --interval 5min
\`\`\`

Then create \`/opt/$REPO_NAME/.env\` from \`.env.example\`.

## Validate locally

On a machine with Docker:

\`\`\`bash
cd $REPO_NAME
/usr/local/bin/docker-git-deploy validate
\`\`\`

Or, before installing the framework, run the framework's CLI directly:

\`\`\`bash
FRAMEWORK_DIR=/path/to/docker-git-deploy/docker-git-deploy \\
  \$FRAMEWORK_DIR/scripts/docker-git-deploy validate
\`\`\`
EOF

log "Created $TARGET_DIR"
log "Push to GitHub: https://github.com/$ORG/$REPO_NAME"
log "Give the README bootstrap command to the user to run on $HOST_NAME"
