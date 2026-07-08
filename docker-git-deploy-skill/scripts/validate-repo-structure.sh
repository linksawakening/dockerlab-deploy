#!/bin/bash
set -euo pipefail

# validate-repo-structure.sh
# Verify that a DEPLOYMENT repo is well-formed pure config. Run from the root of
# a generated deployment repo (not from the framework repo).

fail() { echo "FAIL: $*" >&2; exit 1; }
warn() { echo "WARN: $*" >&2; }

# Required pure-config shape.
[[ -f compose.yaml ]]  || fail "compose.yaml missing at repo root"
[[ -f .env.example ]]  || fail ".env.example missing at repo root"
[[ -f .gitignore ]]    || fail ".gitignore missing at repo root"
[[ -d services ]]      || fail "services/ directory missing at repo root"

# .gitignore must keep secrets out of git.
grep -qE '^\.env$' .gitignore || fail ".gitignore must ignore .env"

# A real .env must never be committed.
if git ls-files --error-unmatch .env >/dev/null 2>&1; then
    fail ".env is tracked by git — remove it and rely on .env.example"
fi
[[ -f .env ]] && warn ".env present locally (fine on a host; ensure it is gitignored)"

# Deployment repos must contain NO executable tooling — that lives in the
# framework (docker-git-deploy-skill/).
for f in install.sh deploy.sh validate.sh health-check.sh test-local.sh \
         bootstrap.sh docker-git-deploy SKILL.md; do
    [[ -e "$f" ]] && fail "Forbidden tooling in a deployment repo: $f"
done
if find . -path ./.git -prune -o \( -name '*.service' -o -name '*.timer' \) -print | grep -q .; then
    fail "Forbidden systemd units in a deployment repo"
fi

echo "OK: deployment repo structure is valid (pure config)"
