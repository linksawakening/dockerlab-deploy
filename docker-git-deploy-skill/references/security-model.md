# docker-git-deploy — Security Model

## Why pull-based

The agent and CI only ever edit the **deployment repo**. The production host
**pulls** and applies changes on a timer. Consequences:

- No SSH or Docker access to the host is handed to the agent or CI.
- The host needs only **outbound HTTPS** to the git host — no inbound ports.
- The only credential on the host is **read-only** Git access to the repo.

## Threat: compromised agent or repo write access

An attacker who can push to the deployment repo can push malicious compose files
or bind-mount paths. Mitigations:

- Branch protection on `main` with required PR review.
- CI validation (`validate` + `install-test`) on every PR.
- The deploy runs as an **unprivileged user** by default (see below).
- Real secrets live only in the host's `.env`, never in the repo.

## Deployment user

By default the systemd timer runs as the unprivileged `docker-git-deploy` user,
which `install.sh` adds to the `docker` group. Note that Docker group
membership is effectively root-equivalent on the host (it grants full control of
the Docker daemon) — this is inherent to running Docker workloads and is why
repo write access and the `.env` must be protected. Passing `--user root` runs
the timer as root explicitly.

## Caveat: the docker socket (autoheal and similar)

The starter's `autoheal` service bind-mounts `/var/run/docker.sock` so it can
restart unhealthy containers. Any container with the socket mounted has
root-equivalent control of the host daemon. Only mount the socket into images
you trust, and pin them by digest if you expose the host to untrusted input.

## Credential scopes

| Credential        | Scope                              | Notes |
|-------------------|------------------------------------|-------|
| Deploy key (SSH)  | Read-only on the deployment repo   | Stored in the deploy user's `~/.ssh`. Works on any git host. |
| Token (HTTPS)     | Read-only on the deployment repo   | If HTTPS is preferred over SSH — e.g. GitHub fine-grained PAT (`contents:read`), GitLab deploy token, Bitbucket app password. |
| `.env` values     | Local to the host                  | Created manually or from a secrets manager; never committed. |
