# prisma-studio-docker

Run [Prisma Studio](https://www.prisma.io/studio) in Docker to browse and edit an external PostgreSQL database.

Repository: [LinkPhoenix/prisma-studio-docker](https://github.com/LinkPhoenix/prisma-studio-docker)

Docker image (GHCR, built on push to `main`):

```
ghcr.io/linkphoenix/prisma-studio-docker:latest
```

## Documentation

### ⚠️ 🚨 Important — VPS + domain/subdomain

> 🔒 **Studio UI** (browser → VPS) — ✅ **Covered by this repo** — HTTPS + basic auth via Traefik → [vps-traefik.md](docs/vps-traefik.md)
>
> 🗄️ **PostgreSQL** (VPS → database) — ❌ **Not covered** — enable **TLS/SSL on PostgreSQL** yourself → [PostgreSQL official SSL docs](https://www.postgresql.org/docs/current/ssl-tcp.html)
>
> 📖 → [Database connection TLS — project notes](docs/security.md#database-connection-tls-vps-deployments) · `sslmode` in `DATABASE_URL`

| Guide | Description |
|-------|-------------|
| [Deployment overview](docs/deployment-overview.md) | All scenarios, decision matrix, architecture |
| [Local development](docs/local-development.md) | Bun, Docker dev, GHCR image locally |
| [VPS direct HTTP warning](docs/vps-direct-http-warning.md) | `crypto.randomUUID` error — why HTTP on public IP fails |
| [VPS Traefik](docs/vps-traefik.md) | **Recommended prod** — HTTPS + basic auth |
| [VPS SSH tunnel](docs/vps-ssh-tunnel.md) | No proxy — tunnel with password or SSH key |
| [Security](docs/security.md) | Basic auth, secrets, firewall, database TLS (VPS) |

## Quick start (local)

```powershell
copy .env.example .env
bun install
bun run db:pull
bun run studio
```

Open http://localhost:5555

Or with Docker: `bun run docker:up`

Full guide: [docs/local-development.md](docs/local-development.md)

## Deployment decision matrix

| Scenario | Compose file | UI works? | Doc |
|----------|--------------|-----------|-----|
| Local dev (Docker) | [`docker-compose.yml`](docker-compose.yml) | Yes | [local-development](docs/local-development.md) |
| Local dev (no Docker) | `bun run studio` | Yes | [local-development](docs/local-development.md) |
| VPS HTTP public `:5555` | [`docker-compose.prod.yml`](docker-compose.prod.yml) | **No** | [vps-direct-http-warning](docs/vps-direct-http-warning.md) |
| VPS Traefik + basic auth | [`docker-compose.prod.traefik.yml`](docker-compose.prod.traefik.yml) | Yes | [vps-traefik](docs/vps-traefik.md) |
| VPS SSH tunnel | [`docker-compose.prod.tunnel.yml`](docker-compose.prod.tunnel.yml) | Yes (localhost) | [vps-ssh-tunnel](docs/vps-ssh-tunnel.md) |

## Scripts

| Script | Description |
|--------|-------------|
| `bun run db:pull` | Introspect database into `schema.prisma` |
| `bun run db:generate` | Generate Prisma Client |
| `bun run studio` | Run Studio locally (no Docker) |
| `bun run docker:up` | Build and start Docker (dev) |
| `bun run docker:down` | Stop Docker containers |
| `bun run docker:logs` | Follow container logs |

## Traefik (recommended for VPS)

Basic auth, HTTPS, and routing are configured **in the compose file** via Traefik labels.

Copy [`.env.traefik.example`](.env.traefik.example) → `.env` on the VPS (or set vars in Portainer). See [docs/vps-traefik.md](docs/vps-traefik.md).

Optional file-provider templates: [`traefik/dynamic/`](traefik/dynamic/)

## References

- [Prisma Docker guide](https://www.prisma.io/docs/guides/deployment/docker)
- [Traefik dashboard security](https://doc.traefik.io/traefik/setup/docker/)
