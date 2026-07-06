# Agent Flow — docker-git-deploy

## Decision tree

```text
User wants docker-git-deploy
│
├─ First time?
│  ├─ Explain prerequisites
│  ├─ Interview user
│  ├─ Generate deployment repo
│  ├─ Add services
│  ├─ Test locally
│  ├─ Push to GitHub
│  └─ Give production install command
│
├─ Add service?
│  ├─ Ask which service
│  ├─ Copy service template
│  ├─ Update compose.yaml and .env.example
│  ├─ Test locally
│  └─ Push
│
├─ Remove service?
│  ├─ Remove from compose.yaml
│  ├─ Validate/test
│  └─ Push
│
└─ Production not deploying?
   ├─ Ask for `systemctl list-timers docker-git-deploy.timer`
   ├─ Ask for `journalctl -u docker-git-deploy.service -n 50`
   └─ Guide fix based on logs
```

## Always do

- Test locally before pushing.
- Keep secrets in `.env`, never in the repo.
- Pin upstream image digests if the user cares about reproducibility.

## Never do

- Run commands on the production host directly.
- Commit real `.env` files.
- Skip validation.
