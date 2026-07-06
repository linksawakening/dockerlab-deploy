# Service Catalog — docker-git-deploy

## Included templates

| Service | File | Notes |
|---------|------|-------|
| `example-service` | `templates/services/example-service/` | nginx smoke-test example |
| `searxng` | `templates/services/searxng/` | SearXNG meta-search engine |

## Adding a service to a deployment repo

Copy the template directory into the deployment repo:

```bash
cp -r ~/.hermes/skills/devops/docker-git-deploy/templates/services/searxng \
      ./services/searxng
```

Update root `compose.yaml`:

```yaml
include:
  - services/searxng/compose.yaml
```

Update `.env.example` with the variables from `services/searxng/.env.example`.

Run:

```bash
./scripts/validate.sh
./scripts/test-local.sh
```

## Creating a new service template

1. Create `templates/services/<name>/compose.yaml`.
2. Create `templates/services/<name>/.env.example`.
3. Add notes about host-side requirements (directories, permissions, secrets).
4. Keep images pinned to a digest if possible.

## Service-specific host requirements

### SearXNG

- Requires `services/searxng/data/settings.yml` on the host.
- Use the template at `templates/services/searxng/data/settings.yml.template`.
- Port defaults to 8080; override with `SEARXNG_PORT`.
