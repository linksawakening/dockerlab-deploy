#!/bin/bash
set -euo pipefail

# test-local.sh — smoke test the deployment repo locally.
# Usage: cd into the deployment repo, then ./scripts/test-local.sh

KEEP="${1:-}"

cd "$(dirname "$0")/.."

echo "==> Validating before test..."
./scripts/validate.sh

echo "==> Pulling images..."
docker compose pull

echo "==> Starting stack..."
docker compose up -d --remove-orphans

echo "==> Running health checks..."
if ./scripts/health-check.sh; then
    echo "==> HEALTH CHECK PASSED"
else
    echo "==> HEALTH CHECK FAILED. Logs:"
    docker compose logs --tail=50
    if [[ "$KEEP" != "--keep" ]]; then
        echo "==> Tearing down..."
        docker compose down --volumes --remove-orphans
    fi
    exit 1
fi

if [[ "$KEEP" != "--keep" ]]; then
    echo "==> Tearing down..."
    docker compose down --volumes --remove-orphans
fi

echo "==> Local test OK"
