# Production Install Commands — docker-git-deploy

## One-line install (HTTPS)

Run as root on the production host:

```bash
curl -fsSL https://raw.githubusercontent.com/armstrys/docker-git-deploy/main/scripts/install.sh | \
  bash -s -- \
    --deployment-repo https://github.com/<ORG>/<REPO>.git \
    --deployment-dir /opt/<HOST>-deploy \
    --user docker-git-deploy \
    --interval 5min
```

## One-line install (SSH)

```bash
curl -fsSL https://raw.githubusercontent.com/armstrys/docker-git-deploy/main/scripts/install.sh | \
  bash -s -- \
    --deployment-repo git@github.com:<ORG>/<REPO>.git \
    --deployment-dir /opt/<HOST>-deploy \
    --user docker-git-deploy \
    --interval 5min
```

## After install

1. Create `.env`:

```bash
sudo cp /opt/<HOST>-deploy/.env.example /opt/<HOST>-deploy/.env
sudo nano /opt/<HOST>-deploy/.env
```

2. Verify timer:

```bash
sudo systemctl list-timers docker-git-deploy.timer
```

3. Watch logs:

```bash
sudo journalctl -u docker-git-deploy.service -f
```

4. Trigger deploy immediately:

```bash
sudo docker-git-deploy deploy --force
```

## Manual uninstall

```bash
sudo systemctl stop docker-git-deploy.timer
sudo systemctl disable docker-git-deploy.timer
sudo rm -f /etc/systemd/system/docker-git-deploy.{service,timer}
sudo rm -f /usr/local/bin/docker-git-deploy
sudo rm -rf /etc/docker-git-deploy
```
