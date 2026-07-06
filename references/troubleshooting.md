# Docker Git Deploy — Troubleshooting

## "Already up to date" but services did not restart

`deploy.sh` only runs `docker compose up` when the local HEAD changes. If you want to force a redeploy (e.g., upstream image tag mutated), run:

```bash
./scripts/deploy.sh --force
```

## Compose validation fails on host but passes locally

The target host may be running a different Docker Compose plugin version. Keep `compose.yaml` compatible with Compose spec 3.8+ and test on the host version before pushing.

## Health check fails after deploy

Check service logs:

```bash
docker compose logs --tail=100 <service>
```

## Deploy loop pulling same commit

This usually means the timer interval is too short and the previous deploy has not finished. Increase `OnUnitInactiveSec` in the systemd timer.

## Permission denied on data directories

The target host user running Docker Compose needs read/write access to bind-mounted directories. Pre-create directories with the correct UID/GID if the container runs as non-root.

## Bootstrap succeeded but nothing is deploying

Confirm the timer is enabled and running:

```bash
systemctl list-timers docker-git-deploy.timer
journalctl -u docker-git-deploy.service -n 50
```

## `.env` values not picked up

Docker Compose reads `.env` from the working directory of the command. If you run `docker compose` from a subdirectory, it will not see the root `.env`. The systemd unit sets `WorkingDirectory` correctly; verify with `systemctl cat docker-git-deploy.service`.
