# prisma-studio-docker

Run [Prisma Studio](https://www.prisma.io/studio) in Docker to browse and edit an external PostgreSQL database. The Docker image is built and published to GHCR on every push to `main`.

Repository: [LinkPhoenix/prisma-studio-docker](https://github.com/LinkPhoenix/prisma-studio-docker)

## Prerequisites

- [Bun](https://bun.sh/)
- [Docker](https://docs.docker.com/) and Docker Compose
- A PostgreSQL database and its connection URL

## Local setup

```powershell
copy .env.example .env
# Edit .env: set DATABASE_URL

bun install
bun run db:pull
```

`db:pull` introspects your database and updates `prisma/schema.prisma`.

Commit the schema so the CI image includes your models:

```powershell
git add prisma/schema.prisma
git commit -m "chore: sync schema from database"
git push origin main
```

## Run locally (Docker)

```powershell
bun run docker:up
```

Open http://localhost:5555

```powershell
bun run docker:logs
bun run docker:down
```

## Deploy on Hetzner (GHCR image)

On the server, only `.env` and `docker-compose.prod.yml` are needed. **Never commit `.env`.**

```bash
mkdir prisma-studio && cd prisma-studio

# Create .env with DATABASE_URL and GITHUB_OWNER
cat > .env << 'EOF'
DATABASE_URL=postgresql://user:password@host:5432/database?schema=public
GITHUB_OWNER=LinkPhoenix
STUDIO_PORT=5555
PRISMA_DB_PULL_ON_START=false
EOF

curl -O https://raw.githubusercontent.com/LinkPhoenix/prisma-studio-docker/main/docker-compose.prod.yml

docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
```

Access: `http://<server-ip>:5555`

## Re-sync schema after database changes

**Option A (recommended):** pull locally, commit, push (rebuilds GHCR image):

```powershell
bun run db:pull
git add prisma/schema.prisma && git commit -m "chore: sync schema" && git push
```

**Option B:** set `PRISMA_DB_PULL_ON_START=true` in server `.env` to introspect on each container start.

## Docker image

Published to GitHub Container Registry:

```
ghcr.io/linkphoenix/prisma-studio-docker:latest
ghcr.io/linkphoenix/prisma-studio-docker:sha-<commit>
```

After the first successful workflow run, ensure the package visibility is **Public** under GitHub → Packages if pulls fail without authentication.

## Security

- Prisma Studio has **no built-in authentication**. Anyone who can reach port 5555 can read and edit data (within DB user permissions).
- Restrict access with your **Hetzner firewall** (allow only trusted IPs or VPN).
- Never commit `.env` or `DATABASE_URL`.
- A public repo exposes table/column names in `schema.prisma`, not row data.

## Scripts

| Script | Description |
|--------|-------------|
| `bun run db:pull` | Introspect database into `schema.prisma` |
| `bun run db:generate` | Generate Prisma Client |
| `bun run studio` | Run Studio locally (no Docker) |
| `bun run docker:up` | Build and start Docker (dev) |
| `bun run docker:down` | Stop Docker containers |
| `bun run docker:logs` | Follow container logs |

## References

- [Prisma Docker guide](https://www.prisma.io/docs/guides/deployment/docker)
