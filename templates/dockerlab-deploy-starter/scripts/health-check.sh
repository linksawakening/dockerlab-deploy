#!/bin/bash
set -uo pipefail

# health-check.sh — basic web health check.
# Override HEALTH_CHECK_URL per service.

URL="${HEALTH_CHECK_URL:-http://localhost:8080}"
TIMEOUT="${HEALTH_CHECK_TIMEOUT:-60}"

echo "Health checking $URL (timeout ${TIMEOUT}s)..."
for ((i=0; i< TIMEOUT; i+=2)); do
    if curl -fsS "$URL" >/dev/null 2>&1; then
        echo "OK: $URL responded"
        exit 0
    fi
    sleep 2
done

echo "ERROR: $URL did not become healthy within ${TIMEOUT}s"
exit 1
