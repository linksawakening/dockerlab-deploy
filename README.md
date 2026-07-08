# docker-git-deploy

Pull-based GitOps for Docker Compose on a single host — with an agent skill.

You edit a **deployment repo** (pure config). The production host runs a systemd
timer that pulls the repo and reconciles the Compose stack with
`docker compose up -d --wait`. No SSH or push access to the host is required; the
host only needs **outbound HTTPS** and **read-only** Git access.

**This repository is the skill and its tooling** — it has no compose config at
its root. The canonical example is bundled at
[docker-git-deploy-skill/assets/starter/](docker-git-deploy-skill/assets/starter/),
which is also the fixture CI deploys and the template new deployment repos are
generated from.

## For agents

Install the skill:

```bash
npx skills add https://github.com/linksawakening/docker-git-deploy --skill docker-git-deploy-skill -a hermes-agent -g -y --copy
```

Then follow the adoption flow in
[docker-git-deploy-skill/SKILL.md](docker-git-deploy-skill/SKILL.md).

## Try it

Generate a deployment repo from the bundled starter, push it, then bootstrap a
host:

```bash
# 1. Generate a pure-config deployment repo (autoheal by default)
docker-git-deploy-skill/scripts/init-deployment.sh \
  --target-dir ~/myhost-deploy --repo-name myhost-deploy \
  --host-name myhost --org <your-org>

# 2. Push it to GitHub (see the generated README)

# 3. On the host, as root:
curl -fsSL https://raw.githubusercontent.com/<your-org>/docker-git-deploy/main/docker-git-deploy-skill/scripts/install.sh | \
  bash -s -- \
    --deployment-repo https://github.com/<your-org>/myhost-deploy.git \
    --deployment-dir /opt/myhost-deploy \
    --interval 5min

# 4. Create /opt/myhost-deploy/.env from .env.example
```

The deploy runs as an unprivileged `docker-git-deploy` user by default (pass
`--user root` to run privileged).

## The example service: autoheal

The starter ships [autoheal](https://github.com/willfarrell/docker-autoheal),
which restarts any container that reports `unhealthy`. Opt a service in by giving
it `labels: [autoheal=true]` and a `healthcheck:`. It's a small, genuinely useful
homelab default and it exercises the health-aware deploy end to end.

## Structure

```text
├── README.md · LICENSE · .gitignore
├── .github/workflows/
│   ├── validate.yaml            # lint the starter compose
│   └── install-test.yaml        # install → deploy → assert autoheal is up
└── docker-git-deploy-skill/     # the skill package (framework + skill + starter)
    ├── SKILL.md
    ├── references/
    ├── scripts/                 # install.sh, docker-git-deploy CLI, init, validate
    └── assets/
        ├── systemd/             # unit templates
        └── starter/             # pure-config example == starter == CI fixture
```

## License

MIT — see [LICENSE](LICENSE).
