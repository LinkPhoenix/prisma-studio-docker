# VPS SSH tunnel

Access Prisma Studio on a VPS **without a reverse proxy** by binding Studio to localhost on the server and forwarding the port over SSH.

Your browser opens `http://localhost:5555` — a secure context — so the Studio UI works without HTTPS on the VPS.

## When to use this

- No Traefik / reverse proxy on the VPS
- Single admin access from your machine
- You accept that **Prisma Studio has no login** (SSH is the only gate)

For team access or persistent URLs, prefer [vps-traefik.md](./vps-traefik.md) (HTTPS + basic auth).

If PostgreSQL is **remote** from the VPS, use a **TLS-encrypted** `DATABASE_URL` (`sslmode`, provider CA, etc.). SSH secures browser → VPS only, not VPS → database. **PostgreSQL TLS/SSL server setup is not covered** — see [PostgreSQL official SSL docs](https://www.postgresql.org/docs/current/ssl-tcp.html) and [security.md — Database connection TLS](./security.md#database-connection-tls-vps-deployments).

---

## Step 1 — Deploy on the VPS

Use [`docker-compose.prod.tunnel.yml`](../docker-compose.prod.tunnel.yml). Studio listens **only** on `127.0.0.1`:

```yaml
ports:
  - "127.0.0.1:5555:5555"
```

Port 5555 is **not** reachable from the internet.

```bash
# On the VPS — edit DATABASE_URL first
docker compose -f docker-compose.prod.tunnel.yml pull
docker compose -f docker-compose.prod.tunnel.yml up -d
```

Or deploy via Portainer with the same compose file.

Verify on the VPS:

```bash
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5555
# Expected: 200
```

---

## Step 2 — Open the SSH tunnel

The tunnel forwards **your** local port 5555 to the VPS localhost port 5555.

Keep the SSH session open while using Studio.

### With password authentication

**Linux / macOS / Git Bash:**

```bash
ssh -N -L 5555:127.0.0.1:5555 user@46.225.80.55
```

**Windows PowerShell** (OpenSSH client):

```powershell
ssh -N -L 5555:127.0.0.1:5555 user@46.225.80.55
```

- `-N` — do not open a remote shell (tunnel only)
- You will be prompted for the SSH password
- Open **http://localhost:5555** in your browser

### With SSH key authentication

**1. Generate a key** (skip if you already have one):

```bash
ssh-keygen -t ed25519 -C "prisma-studio" -f ~/.ssh/prisma_studio_vps
```

**2. Install the public key on the VPS:**

```bash
ssh-copy-id -i ~/.ssh/prisma_studio_vps.pub user@46.225.80.55
```

**Windows** (if `ssh-copy-id` is unavailable):

```powershell
type $env:USERPROFILE\.ssh\prisma_studio_vps.pub | ssh user@46.225.80.55 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

Or manually append the `.pub` content to `~/.ssh/authorized_keys` on the VPS.

**3. Connect with the key:**

```bash
ssh -N -i ~/.ssh/prisma_studio_vps -L 5555:127.0.0.1:5555 user@46.225.80.55
```

Open **http://localhost:5555**.

---

## Step 3 — Optional SSH config

Add to `~/.ssh/config` (Linux/macOS) or `C:\Users\<you>\.ssh\config` (Windows):

```
Host prisma-vps
    HostName 46.225.80.55
    User your-user
    IdentityFile ~/.ssh/prisma_studio_vps
    LocalForward 5555 127.0.0.1:5555
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

Then connect with:

```bash
ssh -N prisma-vps
```

`ServerAliveInterval` helps prevent idle disconnects.

---

## Security notes

| Layer | Protected? |
|-------|------------|
| Network (port 5555) | Yes — bound to 127.0.0.1 on VPS |
| Transport | Yes — SSH encrypts the tunnel |
| Studio login | **No** — anyone on your PC with localhost access can use Studio |
| Database | Uses `DATABASE_URL` credentials |

Recommendations:

- Disable SSH password auth on the VPS; use keys only
- Restrict SSH (port 22) by IP in Hetzner firewall
- Do not expose port 5555 publicly
- For shared or long-term access → use [Traefik + basic auth](./vps-traefik.md)

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `Connection refused` on localhost:5555 | Tunnel not running, or Studio not up on VPS |
| `Address already in use` (local 5555) | Stop local Studio/Docker using 5555, or use `-L 5556:127.0.0.1:5555` and open `:5556` |
| Tunnel drops | Add `ServerAliveInterval` to SSH config |
| UI works but no tables | Schema missing in image — run `db pull`, commit, push |

---

## Related

- [vps-direct-http-warning.md](./vps-direct-http-warning.md) — why public HTTP fails
- [vps-traefik.md](./vps-traefik.md) — production HTTPS + basic auth
- [deployment-overview.md](./deployment-overview.md)
