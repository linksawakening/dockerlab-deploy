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

## How it works

The typical flow, from asking an agent for help to hands-off updates:

```mermaid
sequenceDiagram
    actor Human
    participant Agent
    participant Repo as GitHub<br/>deployment repo
    participant Server as Server<br/>(docker-git-deploy timer)

    Note over Human,Agent: One-time setup
    Human->>Agent: 1. Install the docker-git-deploy skill
    Human->>Agent: 2. Help me deploy services X, Y, Z to my server
    Agent->>Human: 3. Asks about the server; explains minimum<br/>requirements and the GitHub access needed<br/>(agent: WRITE to create the repo · server: READ-ONLY)
    Agent->>Repo: 4. Creates a pure-config deployment repo<br/>(compose + services + .env.example) and pushes it
    Agent->>Human: 5. Gives the one-line install command
    Human->>Server: Runs it as root (clones repo, installs timer)
    Human->>Server: Creates .env with real secrets (never in the repo)
    Server->>Repo: Reads (read-only) — agent never touches the server again

    Note over Repo,Server: Steady state — every poll interval (e.g. 5 min)
    loop
        Server->>Repo: git fetch origin/main
        alt new commit on main
            Server->>Server: reset, pull images,<br/>up -d --wait (roll back if unhealthy)
        else no change
            Server->>Server: reconcile (idempotent)
        end
    end

    Note over Human,Repo: 6. Ongoing changes
    Human->>Repo: Edit config from anywhere (or ask the agent),<br/>open a PR, merge to main
    Repo-->>Server: Applied automatically on the next poll
```

1. **Install the skill.** The human asks the agent to install this skill.
2. **State the goal.** The human asks the agent to deploy services X, Y, Z to a server.
3. **Scope it.** The agent asks about the current server, explains the [minimum
   requirements](docker-git-deploy-skill/references/prerequisites.md), and
   explains the GitHub access involved — the **agent needs write** access to
   create and push the deployment repo, while the **server only needs read-only**
   access to pull it.
4. **Create the deployment repo.** The agent generates a pure-config repo from
   the starter (compose files, service definitions, `.env.example`) and pushes it
   to GitHub.
5. **Bootstrap the server.** The agent hands the human a one-line install command
   to run as root on the server; it clones the repo and installs the systemd
   timer. The human then creates `.env` on the server with real secrets (the
   deploy is skipped until it exists — secrets never live in the repo). The agent
   helps troubleshoot but never needs access to the server itself.
6. **Hands-off updates.** From then on, the human (or the agent) changes service
   config in the repo from anywhere and merges to `main`. The server polls
   `origin/main` on its timer and applies the change automatically — reconciling
   with `docker compose up -d --wait` and rolling back if the new version fails to
   become healthy.

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
