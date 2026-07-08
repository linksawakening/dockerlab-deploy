# Design Constraints — docker-git-deploy

Hard-won architectural guardrails. Future edits must preserve these.

## 1. The repo is a skill package; the deployment repo is separate

This repository is the **skill and its tooling** — nothing more. It has no
compose config at its root. Everything ships under `docker-git-deploy-skill/`:

```text
docker-git-deploy-skill/
├── SKILL.md
├── references/
├── scripts/            # install.sh, docker-git-deploy CLI, init/validate
└── assets/
    ├── systemd/        # unit templates (*.in)
    └── starter/        # the pure-config example == starter == CI fixture
```

Real deployments live in a **separate** repo the user owns, generated from
`assets/starter/` by `scripts/init-deployment.sh`.

## 2. One starter, three roles

`assets/starter/` is the single canonical example. It is simultaneously:

1. what `init-deployment.sh` copies to seed a user's deployment repo,
2. the fixture the `install-test` CI workflow deploys, and
3. the thing that ships with the skill when installed via `npx skills add`.

Because it lives **inside** the skill folder, it travels with the skill. Never
reintroduce a second copy at the repo root — that was the bug that broke
standalone skill installs.

## 3. Deployment repos are pure config

A deployment repo contains **only**: `compose.yaml`, `.env.example`,
`.gitignore`, `README.md`, optional minimal `.github/workflows/`, and
`services/<name>/compose.yaml` (+ service data). It must **never** contain
install/deploy scripts, systemd units, or any executable tooling. All tooling
lives in the framework. `scripts/validate-repo-structure.sh` enforces this.

## 4. Deploy is a declarative reconcile

`docker-git-deploy deploy` always runs `docker compose up -d --remove-orphans
--wait`, even when the git commit has not changed, so the stack converges on the
first tick after install and self-heals crashed containers. Images are pulled
only when the commit changed or `--force` is passed. `--wait` makes an unhealthy
stack a deploy failure; a failed update rolls back to the previous commit.

## 5. CI must exercise the real install path

Every change must pass a workflow that materializes `assets/starter/` into a
throwaway git repo, runs `install.sh` against it, deploys, and **asserts the
service is actually up** — not just that compose parses. Static compose
validation alone is insufficient.

Pitfall: do **not** use `docker/setup-docker-action@v4` in CI; it can leave
iptables chains half-initialized so `docker compose` cannot create networks. Use
the Docker preinstalled on `ubuntu-latest` runners.
