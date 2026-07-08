#!/bin/bash
set -euo pipefail

# init-deployment.sh
# Generate a pure-config deployment repo from the bundled starter.
#
# Flags (any omitted value falls back to $ENV, then an interactive prompt):
#   --target-dir <dir>   Where to create the new deployment repo
#   --repo-name <name>   GitHub repo name (for the bootstrap URL)
#   --host-name <host>   Production host name (for docs)
#   --org <org>          Git host org/user (for the example URLs)
#   --repo-url <url>     Full git URL of the deployment repo (any git host).
#                        Defaults to https://github.com/<org>/<repo>.git

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"  # .../docker-git-deploy-skill
STARTER_DIR="$SKILL_DIR/assets/starter"

log() { echo "[docker-git-deploy] $*"; }
fail() { log "ERROR: $*"; exit 1; }

TARGET_DIR="${TARGET_DIR:-}"
REPO_NAME="${REPO_NAME:-}"
HOST_NAME="${HOST_NAME:-}"
ORG="${ORG:-}"
REPO_URL="${REPO_URL:-}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target-dir) TARGET_DIR="$2"; shift 2 ;;
        --repo-name) REPO_NAME="$2"; shift 2 ;;
        --host-name) HOST_NAME="$2"; shift 2 ;;
        --org) ORG="$2"; shift 2 ;;
        --repo-url) REPO_URL="$2"; shift 2 ;;
        -h|--help) grep '^#' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) fail "Unknown argument: $1" ;;
    esac
done

[[ -d "$STARTER_DIR" ]] || fail "Starter template not found at $STARTER_DIR"

# Prompt for anything still missing (skipped in non-interactive contexts where
# all values are supplied via flags or env).
[[ -z "$TARGET_DIR" ]] && read -rp "Target directory for deployment repo: " TARGET_DIR
[[ -z "$REPO_NAME"  ]] && read -rp "Deployment repo name: " REPO_NAME
[[ -z "$HOST_NAME"  ]] && read -rp "Production host name: " HOST_NAME
[[ -z "$ORG"        ]] && read -rp "Git host org/user: " ORG

[[ -n "$TARGET_DIR" ]] || fail "target-dir is required"
[[ -n "$REPO_NAME"  ]] || fail "repo-name is required"
[[ -n "$HOST_NAME"  ]] || fail "host-name is required"
[[ -n "$ORG"        ]] || fail "org is required"

# Deployment repo URL: any git host. Default to a GitHub HTTPS URL from --org.
REPO_URL="${REPO_URL:-https://github.com/$ORG/$REPO_NAME.git}"

TARGET_DIR="$(cd "$(dirname "$TARGET_DIR")" && pwd)/$(basename "$TARGET_DIR")"
[[ -e "$TARGET_DIR" ]] && fail "$TARGET_DIR already exists"

cp -r "$STARTER_DIR" "$TARGET_DIR"

# Replace the generic starter README with one specific to this host.
cat > "$TARGET_DIR/README.md" <<EOF
# $REPO_NAME

Docker Git deployment configuration for **$HOST_NAME**. Pure config: the host
polls this repo and applies \`compose.yaml\` automatically.

## Bootstrap on $HOST_NAME

Run as root:

\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/linksawakening/docker-git-deploy/main/docker-git-deploy-skill/scripts/install.sh | \\
  bash -s -- \\
    --deployment-repo $REPO_URL \\
    --deployment-dir /opt/$REPO_NAME \\
    --interval 5min
\`\`\`

Then create the environment file:

\`\`\`bash
sudo cp /opt/$REPO_NAME/.env.example /opt/$REPO_NAME/.env
sudo nano /opt/$REPO_NAME/.env
\`\`\`

## Validate locally

From a machine with Docker and the framework checked out:

\`\`\`bash
FRAMEWORK_DIR=/path/to/docker-git-deploy/docker-git-deploy-skill
cd $REPO_NAME && docker compose config >/dev/null && echo Valid
\`\`\`
EOF

log "Created deployment repo at $TARGET_DIR"
log ""
log "Next steps:"
log "  1. cd $TARGET_DIR"
log "  2. git init && git add . && git commit -m 'initial docker-git-deploy deploy'"
log "  3. git remote add origin $REPO_URL"
log "  4. git push -u origin main"
log "  5. Give the README bootstrap command to run on $HOST_NAME"
