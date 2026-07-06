# docker-git-deploy starter deployment repo

This is the smallest possible deployment repo. Replace with your services.

## Layout

```text
├── compose.yaml
├── .env.example
├── .gitignore
└── services/
```

## Usage

1. Add service compose files under `services/<name>/compose.yaml`.
2. Include them in root `compose.yaml`.
3. Add required env vars to `.env.example`.
4. Validate with the docker-git-deploy tool or standard Docker Compose commands.

The bootstrap command is in the generated README for the target host.
