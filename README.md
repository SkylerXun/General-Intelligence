# New API Gateway

This repository deploys and maintains New API only. The `new-api` directory is a
pinned Git submodule; runtime secrets in `env/*.env` are intentionally ignored.

Clone it with:

```powershell
git clone --recurse-submodules https://github.com/SkylerXun/General-Intelligence.git gateway
```

For local Docker testing in WSL Ubuntu:

```powershell
wsl -d Ubuntu -- bash /mnt/d/gateway/scripts/init-local.sh
wsl -d Ubuntu -- bash /mnt/d/gateway/scripts/local-up.sh
wsl -d Ubuntu -- bash /mnt/d/gateway/scripts/smoke-test.sh local
```

The local New API endpoint is `http://localhost:3100`. Stop the stack while
keeping its volumes with `scripts/local-down.sh`.

For production, copy `env/production.env.example` to the ignored
`env/production.env`, replace every placeholder with secure values, then run:

```bash
docker compose --project-name gateway --env-file env/production.env \
  -f docker/compose.yaml -f docker/compose.prod.yaml up -d --build
bash scripts/smoke-test.sh prod
```

Operational details and migration commands are in [docs/operations.md](docs/operations.md).
