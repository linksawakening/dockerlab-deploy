#!/bin/bash
set -euo pipefail

# validate.sh — validate a deployment repo locally.
# Usage: cd into the deployment repo, then ./scripts/validate.sh

cd "$(dirname "$0")/.."

echo "==> Validating compose configuration..."
docker compose config >/dev/null

echo "==> OK"
