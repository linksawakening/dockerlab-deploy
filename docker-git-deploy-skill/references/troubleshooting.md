# docker-git-deploy — Troubleshooting

## Force a redeploy without a new commit

`deploy` always reconciles the stack, but only pulls images when the commit
changed. To re-pull and re-apply anyway (e.g. a `:latest` tag moved):

```bash
docker-git-deploy deploy --force
```

## Stack did not become healthy / deploy rolled back

`deploy` runs `docker compose up -d --wait`. If a container never reports
healthy within `WAIT_TIMEOUT` (default 120s), the deploy fails; if the failure
followed a new commit, it rolls back to the previous commit automatically.
Inspect the failing service:

```bash
docker-git-deploy logs --tail=100 <service>
```

Raise the timeout for slow-starting stacks:

```bash
WAIT_TIMEOUT=300 docker-git-deploy deploy --force
```

## autoheal is not restarting a container

autoheal only watches a container when it **both** carries the watch label and
defines a healthcheck:

```yaml
    labels:
      - autoheal=true          # must match AUTOHEAL_CONTAINER_LABEL
    healthcheck:
      test: ["CMD", "curl", "-fsS", "http://localhost:8080/health"]
```

Confirm autoheal is running and check its logs: `docker-git-deploy logs autoheal`.

## Nothing deploys after bootstrap

The deploy is skipped until `<deployment-dir>/.env` exists. Create it, then
confirm the timer:

```bash
systemctl list-timers docker-git-deploy.timer
journalctl -u docker-git-deploy.service -n 50
```

## Wrong poll interval

The interval is baked into the timer at install time from `--interval`. Change
it by editing `OnUnitInactiveSec` in `/etc/systemd/system/docker-git-deploy.timer`,
then `systemctl daemon-reload`. Verify with `systemctl cat docker-git-deploy.timer`.

## `.env` values not picked up

Compose reads `.env` from its working directory. The systemd service sets
`WorkingDirectory` to the deployment directory, and the CLI also `cd`s there, so
this should be correct — verify with `systemctl cat docker-git-deploy.service`.

## Permission denied on bind-mounted data

When running as the unprivileged `docker-git-deploy` user, pre-create
bind-mounted directories with the right UID/GID, or run `--user root`.

## GitHub Actions install test fails with an iptables chain error

If a workflow uses `docker/setup-docker-action@v4`, a custom daemon can start
without initializing iptables, and Compose fails with:

```
failed to create network ..._default:
  Chain 'DOCKER-ISOLATION-STAGE-2' does not exist
```

Fix: drop that action and use the Docker preinstalled on `ubuntu-latest`.

## CI fails and looks like a network error

Runner networking is rarely the cause. Common culprits: the setup-docker action
above, missing env vars for `docker compose config`, or `docker-compose` (legacy
binary) instead of `docker compose`.
