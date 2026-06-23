# Local development

Run Prisma Studio on your machine to browse and edit a PostgreSQL database (local or remote).

## Prerequisites

- [Bun](https://bun.sh/)
- [Docker](https://docs.docker.com/) (optional, for containerized dev)
- PostgreSQL connection URL

## Initial setup

```powershell
copy .env.example .env
# Edit .env: set DATABASE_URL

bun install
bun run db:pull
```

`db:pull` introspects your database and updates [`prisma/schema.prisma`](../prisma/schema.prisma).

Commit the schema so the CI image includes your models:

```powershell
git add prisma/schema.prisma
git commit -m "chore: sync schema from database"
git push origin main
```

---

## Option A — Without Docker (simplest)

Run Studio directly on your machine:

```powershell
bun run studio
```

Open **http://localhost:5555**

Why it works: browsers treat `http://localhost` as a [secure context](https://developer.mozilla.org/en-US/docs/Web/Security/Secure_Contexts), so Prisma Studio's UI can use `crypto.randomUUID()`.

Your `DATABASE_URL` can point to a remote database (Neon, Hetzner, etc.) as long as the database accepts connections from your IP.

Stop with `Ctrl+C`.

---

## Option B — Docker dev (build from source)

Uses [`docker-compose.yml`](../docker-compose.yml) — builds the image locally and mounts schema volumes.

```powershell
bun run docker:up
```

Open **http://localhost:5555**

Useful commands:

```powershell
bun run docker:logs    # follow container logs
bun run docker:down    # stop containers
```

Volumes:

- `./prisma` → live schema updates without rebuild
- `./generated` → generated Prisma Client

Environment is loaded from [`.env`](../.env) via `env_file`.

---

## Option C — Test the GHCR production image locally

Pull and run the same image used on the VPS:

```powershell
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
```

Open **http://localhost:5555** (localhost only — do not expose this compose on a public IP).

```powershell
docker compose -f docker-compose.prod.yml down
```

---

## Schema sync workflow

When the database schema changes:

```powershell
bun run db:pull
git add prisma/schema.prisma
git commit -m "chore: sync schema from database"
git push origin main
```

GitHub Actions rebuilds and publishes a new GHCR image.

For dev Docker with mounted volumes, restart after pull:

```powershell
docker compose restart prisma-studio
```

---

## Scripts reference

| Script | Description |
|--------|-------------|
| `bun run db:pull` | Introspect database into `schema.prisma` |
| `bun run db:generate` | Generate Prisma Client |
| `bun run studio` | Run Studio locally (no Docker) |
| `bun run docker:up` | Build and start Docker (dev) |
| `bun run docker:down` | Stop Docker containers |
| `bun run docker:logs` | Follow container logs |

---

## Next steps

- Deploy to a VPS: [deployment-overview.md](./deployment-overview.md)
- Production with Traefik: [vps-traefik.md](./vps-traefik.md)
