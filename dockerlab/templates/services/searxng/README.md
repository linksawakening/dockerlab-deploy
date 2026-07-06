# SearXNG service template

This directory contains a minimal SearXNG service definition.

## Files

- `compose.yaml` — SearXNG container definition.
- `.env.example` — Required environment variables.
- `settings.yml.template` — SearXNG settings template.

## Required on target host

Create `services/searxng/data/settings.yml` from the template and mount it into the container. The path is relative to the service's `compose.yaml`:

```text
services/searxng/
├── compose.yaml
├── .env.example
├── README.md
└── data/
    └── settings.yml
```

## Configuration notes

- `secret_key` is disabled in this template; set it in production if you expose SearXNG publicly.
- Rate limiting is disabled for local/private use.
