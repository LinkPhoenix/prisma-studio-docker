# VPS deployment with Traefik

**Recommended production setup.** Traefik provides HTTPS (fixes the Studio UI secure context requirement) and basic authentication via **Docker labels in the compose file** — no `/opt/traefik/dynamic/` file required for Prisma Studio.

## Overview

```mermaid
flowchart LR
  Browser -->|"https + basic auth"| Traefik["Traefik"]
  Traefik -->|"http internal"| Studio["prisma-studio:5555"]
  Studio --> DB["PostgreSQL external"]
```

[`docker-compose.prod.traefik.yml`](../docker-compose.prod.traefik.yml) defines the router, TLS, and `basicAuth` middleware as Traefik labels on the container — the same mechanism as the [Traefik dashboard with Docker labels](https://doc.traefik.io/traefik/setup/docker/).

---

## Prerequisites

Traefik already running on the VPS with:

- Docker provider (`exposedByDefault: false`)
- Entrypoints `web` (→ redirect HTTPS) and `websecure` (443)
- Certificate resolver named `cloudflare` in Traefik static config
- External Docker network (default name: `traefik`)

Example static config excerpt:

```yaml
entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
          permanent: true
  websecure:
    address: ":443"

providers:
  docker:
    exposedByDefault: false
    network: traefik

certificatesResolvers:
  cloudflare:
    acme:
      email: you@example.com
      storage: /opt/traefik/acme.json
      dnsChallenge:
        provider: cloudflare
        # CLOUDFLARE_DNS_API_TOKEN env on Traefik container
```

---

## Step 1 — Generate basic auth credentials

Prisma Studio has **no built-in login**. Generate an htpasswd line:

```bash
docker run --rm httpd:2.4-alpine htpasswd -nbB admin 'YOUR_STRONG_PASSWORD'
```

Output example:

```
admin:$2y$05$xyz...
```

**Multiple users:** comma-separate entries:

```
admin:$2y$05$...,editor:$2y$05$...
```

---

## Step 2 — Configure environment variables

Set these in Portainer (**Stack → Environment variables**) or copy [`.env.traefik.example`](../.env.traefik.example) → `.env` on the VPS:

| Variable | Example | Description |
|----------|---------|-------------|
| `DATABASE_USER` | `myuser` | PostgreSQL user |
| `DATABASE_PASSWORD` | `secret` | PostgreSQL password |
| `DATABASE_HOST` | `db.example.com` | PostgreSQL host |
| `DATABASE_PORT` | `5432` | PostgreSQL port (default: 5432) |
| `DATABASE_NAME` | `mydb` | PostgreSQL database name |
| `DATABASE_SCHEMA` | `public` | Schema (default: public) |
| `DATABASE_URL` | *(optional)* | Full URL — overrides the variables above if set |
| `STUDIO_HOST` | `studio.example.com` | Subdomain for Traefik router rule |
| `BASIC_AUTH_USERS` | `admin:$2y$05$...` | htpasswd output from step 1 |
| `TRAEFIK_CERT_RESOLVER` | `cloudflare` | Certificate resolver name in Traefik static config |
| `TRAEFIK_NETWORK` | `traefik` | External Docker network name |
| `PRISMA_DB_PULL_ON_START` | `false` | Optional schema re-introspection |

Point DNS `STUDIO_HOST` → VPS IP. Open ports **80** and **443** on your firewall.

**Portainer tip:** paste `BASIC_AUTH_USERS` as-is (with `$` characters). Do not commit this value to Git.

---

## Step 3 — Deploy the stack

### Portainer

1. **Stacks → Add stack**
2. Paste [`docker-compose.prod.traefik.yml`](../docker-compose.prod.traefik.yml)
3. Add environment variables from step 2 (database + Traefik + `BASIC_AUTH_USERS`)
4. Deploy

### CLI

Copy the example env file on the VPS:

```bash
cp .env.traefik.example .env
nano .env   # DATABASE_USER, DATABASE_PASSWORD, DATABASE_HOST, DATABASE_NAME, etc.
```

[`.env.traefik.example`](../.env.traefik.example)

```bash
docker compose -f docker-compose.prod.traefik.yml pull
docker compose -f docker-compose.prod.traefik.yml up -d
```

---

## What the compose labels do

All Traefik routing is defined in the compose file:

```yaml
labels:
  - traefik.enable=true
  - traefik.http.routers.prisma-studio.rule=Host(`${STUDIO_HOST}`)
  - traefik.http.routers.prisma-studio.entrypoints=websecure
  - traefik.http.routers.prisma-studio.tls=true
  - traefik.http.routers.prisma-studio.tls.certresolver=${TRAEFIK_CERT_RESOLVER:-cloudflare}
  - traefik.http.routers.prisma-studio.middlewares=prisma-studio-auth
  - traefik.http.middlewares.prisma-studio-auth.basicauth.users=${BASIC_AUTH_USERS}
  - traefik.http.services.prisma-studio.loadbalancer.server.port=5555
```

No port 5555 is published on the host — Traefik proxies HTTPS internally.

---

## Step 4 — Verify

1. Open `https://studio.example.com` (your `STUDIO_HOST`)
2. Browser prompts for **basic auth** (admin / your password)
3. Prisma Studio UI loads — no `crypto.randomUUID` error
4. Tables visible (schema must be in the GHCR image)

---

## Alternative — file provider (`/opt/traefik/dynamic/`)

If you prefer centralised Traefik config on disk (e.g. shared `dashboard-auth` middleware with the Traefik dashboard), use the templates in [`traefik/dynamic/`](../traefik/dynamic/) instead of compose labels. Remove the router/middleware labels from compose and keep only:

```yaml
labels:
  - traefik.enable=true
  - traefik.docker.network=traefik
  - traefik.http.services.prisma-studio.loadbalancer.server.port=5555
```

See [`traefik/dynamic/prisma-studio.yml.example`](../traefik/dynamic/prisma-studio.yml.example).

---

## Troubleshooting

| Issue | Check |
|-------|-------|
| 404 from Traefik | Container on `TRAEFIK_NETWORK`? `traefik.enable=true`? |
| No basic auth prompt | `BASIC_AUTH_USERS` set? `$` in hash not stripped by Portainer? |
| 401 always | Wrong password or corrupted hash (re-generate htpasswd) |
| UI crash / randomUUID | URL must be `https://`, not `http://` |
| Empty Studio (no models) | Run `db pull`, commit schema, push to rebuild GHCR image |
| Wrong network | Set `TRAEFIK_NETWORK=proxy` (or your network name) |

---

## Related

- [vps-direct-http-warning.md](./vps-direct-http-warning.md) — why plain HTTP fails
- [security.md](./security.md) — auth and firewall guidance
- [deployment-overview.md](./deployment-overview.md) — all deployment options
