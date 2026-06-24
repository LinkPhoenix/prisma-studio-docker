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

### Traefik on the VPS

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

### PostgreSQL TLS/SSL (your responsibility)

This guide sets up **HTTPS for `STUDIO_HOST`** (browser → Traefik → Studio). It does **not** set up **TLS/SSL for PostgreSQL** (`DATABASE_HOST`, server certificates, `ssl` in `postgresql.conf`, etc.).

When Studio runs on a VPS and PostgreSQL is remote, use a **TLS-encrypted connection** and the appropriate certificate trust. Add `sslmode` (and `sslrootcert` if needed) to `DATABASE_URL` in the VPS `.env` or Portainer secrets.

**PostgreSQL server TLS/SSL installation is not covered by this project.** Refer to the official documentation:

→ [PostgreSQL — Secure TCP/IP Connections with SSL](https://www.postgresql.org/docs/current/ssl-tcp.html)

Example client-side URL (after PostgreSQL TLS is enabled on the server):

```
DATABASE_URL=postgresql://user:password@db.example.com:5432/mydb?schema=public&sslmode=require
```

Mounting CA files into the Docker container is also out of scope. Details: [security.md — Database connection TLS](./security.md#database-connection-tls-vps-deployments).

---

## Step 1 — Generate basic auth credentials

Prisma Studio has **no built-in login**. Generate an htpasswd line on the VPS.

### Recommended — `apache2-utils` on the VPS

```bash
sudo apt install apache2-utils

htpasswd -nbB admin 'YOUR_STRONG_PASSWORD'
```

Output example:

```
admin:$2y$05$xyz...
```

Paste the full line into `.env` as `BASIC_AUTH_USERS="admin:$2y$05$..."`.

**Multiple users:** comma-separate entries:

```
admin:$2y$05$...,editor:$2y$05$...
```

### Alternative — Docker (no apt install)

```bash
docker run --rm httpd:2.4-alpine htpasswd -nbB admin 'YOUR_STRONG_PASSWORD'
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
| `DATABASE_URL` | *(optional)* | Full URL — overrides the variables above if set; add `sslmode=require` (or stricter) for remote DB TLS |
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

1. Check the basic auth label on the container:

```bash
docker inspect prisma-studio | grep -i basicauth -A 2
```

You should see `traefik.http.middlewares.prisma-studio-auth.basicauth.users` with your `user:hash` (not empty).

2. Open `https://studio.example.com` (your `STUDIO_HOST`)
3. Browser prompts for **basic auth** (admin / your password)
4. Prisma Studio UI loads — no `crypto.randomUUID` error
5. Tables visible (schema must be in the GHCR image)

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
