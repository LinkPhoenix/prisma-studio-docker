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
| HTTPS | Required for Studio UI (see [vps-direct-http-warning.md](./vps-direct-http-warning.md)) |
| Basic auth | `BASIC_AUTH_USERS` in stack env (compose labels) or Traefik `usersfile` |
| Public port 5555 | **Do not expose** — use Traefik or SSH tunnel |
| Firewall (Hetzner) | Allow 443 (Traefik); restrict SSH to trusted IPs |
| `DATABASE_URL` | Server `.env` / Portainer secrets only — **never commit** |
| PostgreSQL user | Minimum privileges needed (read-only if edits not required) |
| GitHub repo | Public `schema.prisma` exposes table/column names, not row data |

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
