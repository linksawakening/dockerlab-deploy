# Docker Git Deploy — Security Model

## Threat: agent compromise

If the agent editing the repo is compromised, an attacker can push malicious compose files or mount paths. Mitigations:

- Branch protection on `main` with required PR reviews.
- CI validation runs on every PR.
- The target host runs as an unprivileged user where possible.
- `.env` secrets are never in the repo.

## Credential scopes

| Credential | Scope | Notes |
|------------|-------|-------|
| Deploy key (SSH) | Read-only access to deploy repo | Stored in `~/.ssh` on target host. |
| GitHub PAT | `contents:read` only | Only if HTTPS polling is preferred. |
| `.env` values | Local to target host | Created manually or via a separate secrets mechanism. |

## Network exposure

This pattern requires only outbound HTTPS from target host to GitHub. No inbound ports need to be open.
