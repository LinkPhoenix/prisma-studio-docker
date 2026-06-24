# Security

Prisma Studio provides **direct read/write access** to your PostgreSQL database through a web UI. Treat it as a sensitive admin tool.

## No built-in authentication

Prisma Studio does not support user accounts, sessions, or API keys. Anyone who can load the UI can browse and edit data (within the PostgreSQL user's permissions).

**Strongly recommended for production:** place Studio behind **Traefik HTTPS + basic auth**, using the same pattern as the Traefik dashboard.

→ Full procedure: [vps-traefik.md](./vps-traefik.md)

---

## Production checklist

| Control | Recommendation |
|---------|----------------|
| HTTPS (Studio UI) | Required when accessed via domain/subdomain (see [vps-direct-http-warning.md](./vps-direct-http-warning.md)) |
| Basic auth | `BASIC_AUTH_USERS` in stack env (compose labels) or Traefik `usersfile` |
| Public port 5555 | **Do not expose** — use Traefik or SSH tunnel |
| Firewall (Hetzner) | Allow 443 (Traefik); restrict SSH to trusted IPs |
| `DATABASE_URL` | Server `.env` / Portainer secrets only — **never commit** |
| PostgreSQL TLS | **Required** when Studio runs on a VPS and the DB is remote — see below |
| PostgreSQL user | Minimum privileges needed (read-only if edits not required) |
| GitHub repo | Public `schema.prisma` exposes table/column names, not row data |

---

## Database connection TLS (VPS deployments)

When Prisma Studio runs on a **VPS** and you access it through a **domain or subdomain** (Traefik HTTPS, or any public-facing setup), the connection from the VPS container to PostgreSQL should be **encrypted with TLS**.

This project secures **browser → Studio** (HTTPS + basic auth via Traefik). It does **not** configure **Studio → PostgreSQL** TLS — that is your responsibility.

### Why it matters

- Credentials and query data travel over the network between the VPS and the database host.
- Managed PostgreSQL providers (Neon, Supabase, RDS, etc.) often **require** TLS for remote connections.
- Encrypting the UI (HTTPS) does **not** encrypt the database link — both layers are independent.

### What you must configure yourself

1. **Enable TLS/SSL on PostgreSQL** (or use a managed provider that exposes TLS on port 5432).  
   **This repository does not cover PostgreSQL installation or server-side TLS/SSL setup.**  
   → Official guide: [PostgreSQL — Secure TCP/IP Connections with SSL](https://www.postgresql.org/docs/current/ssl-tcp.html)
2. **Obtain or trust the server certificate** (provider CA bundle, or your own CA if self-hosted).
3. **Set `sslmode` (and related params) in `DATABASE_URL`** on the VPS, for example:

   ```
   postgresql://user:password@db.example.com:5432/mydb?schema=public&sslmode=require
   ```

   Stricter verification (recommended when you have the CA file):

   ```
   postgresql://user:password@db.example.com:5432/mydb?schema=public&sslmode=verify-full&sslrootcert=/path/to/ca.pem
   ```

4. **Mount the CA certificate into the container** if your provider or `sslmode=verify-full` requires a file on disk (not covered by this repo’s compose files).

Refer to:

- [PostgreSQL — Secure TCP/IP Connections with SSL](https://www.postgresql.org/docs/current/ssl-tcp.html) (server TLS/SSL setup — **not covered by this repo**)
- Your database provider’s documentation (Neon, Supabase, RDS, etc.)
- [Prisma’s PostgreSQL connection URL reference](https://www.prisma.io/docs/orm/overview/databases/postgresql#connection-details) (`sslmode`, client-side params)

### Out of scope for this repository

| Topic | Covered here? |
|-------|----------------|
| Traefik HTTPS for `STUDIO_HOST` | Yes — [vps-traefik.md](./vps-traefik.md) |
| Basic auth in front of Studio | Yes — [vps-traefik.md](./vps-traefik.md) |
| PostgreSQL installation with TLS/SSL | **No** — see [PostgreSQL SSL docs](https://www.postgresql.org/docs/current/ssl-tcp.html) |
| CA / client certificate provisioning | **No** |
| Mounting `sslrootcert` in Docker | **No** |

Local development (`localhost` → local Postgres) may use a non-TLS connection; production VPS → remote database should not.

---

## Deployment-specific risks

### Traefik + basic auth (recommended)

- Login prompt before Studio loads
- TLS encrypts traffic
- Shared `usersfile` can protect dashboard and Studio with the same credentials (file-provider setup)
- With compose labels: set `BASIC_AUTH_USERS` in stack environment (see [vps-traefik.md](./vps-traefik.md))
- Rotate passwords by updating `BASIC_AUTH_USERS` and redeploying the stack

### SSH tunnel

- Port 5555 not public on VPS
- SSH secures transport
- **No Studio login** — protection relies on SSH access control
- Prefer SSH keys over passwords; disable password auth on the VPS

### Direct HTTP on public IP (never)

- Studio UI broken (`crypto.randomUUID`)
- Even if it worked, no authentication
- See [vps-direct-http-warning.md](./vps-direct-http-warning.md)

### Local development

- `http://localhost:5555` is fine on your machine
- Ensure `.env` is in `.gitignore`

---

## Secrets handling

```powershell
# Good
copy .env.example .env
# Edit .env locally — never git add .env

# Bad
git add .env
DATABASE_URL in docker-compose committed to Git
```

In Portainer: use stack environment variables or secrets, not hardcoded passwords in version-controlled compose files.

---

## Database user permissions

If you only need to **view** data, create a PostgreSQL role with `SELECT` only. Studio will hide write actions only if the DB user lacks `INSERT`/`UPDATE`/`DELETE` privileges.

For **edit** access, use a dedicated user with scoped permissions — not your application superuser.

---

## Related

- [vps-traefik.md](./vps-traefik.md) — basic auth setup
- [vps-ssh-tunnel.md](./vps-ssh-tunnel.md) — tunnel security limits
- [deployment-overview.md](./deployment-overview.md)
