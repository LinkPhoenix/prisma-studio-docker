# Traefik file-provider templates (optional)

**Recommended:** basic auth and routing via labels in [`docker-compose.prod.traefik.yml`](../docker-compose.prod.traefik.yml) — see [docs/vps-traefik.md](../docs/vps-traefik.md).

Use the templates below only if you prefer `/opt/traefik/dynamic/` (shared with Traefik dashboard file config).

| File | Destination |
|------|-------------|
| [`dynamic/dashboard-auth.yml.example`](dynamic/dashboard-auth.yml.example) | `/opt/traefik/dynamic/dashboard-auth.yml` |
| [`dynamic/prisma-studio.yml.example`](dynamic/prisma-studio.yml.example) | `/opt/traefik/dynamic/prisma-studio.yml` |
