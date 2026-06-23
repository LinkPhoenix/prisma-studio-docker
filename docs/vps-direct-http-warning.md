# VPS direct HTTP — UI crash warning

This document explains why exposing Prisma Studio on `http://<public-ip>:5555` **does not work**, even when the Docker container is healthy.

## Compose file involved

[`docker-compose.prod.yml`](../docker-compose.prod.yml) exposes port `5555` on all interfaces:

```yaml
ports:
  - "5555:5555"
```

This is acceptable **only** on `localhost` for testing. **Never** use this on a VPS with a public IP without HTTPS or an SSH tunnel.

---

## Symptom

The container logs show Studio is running:

```
Prisma Studio is running at: http://localhost:5555
```

But the browser shows a blank page and this error in the console:

```
studio.js:27 Uncaught TypeError: crypto.randomUUID is not a function
    at studio.js:27:106634
    at Array.forEach (<anonymous>)
    at iPe.insert (studio.js:27:106450)
    at yz.insert (studio.js:27:111520)
    at studio.js:33:24190
    at IS (studio.js:8:93244)
    at uve (studio.js:8:108538)
    at Ml (studio.js:8:108420)
    at uve (studio.js:8:108518)
    at Ml (studio.js:8:108420)
```

## Diagnose in the browser console

Run this on the broken page:

```javascript
console.log({
  protocol: location.protocol,
  isSecureContext,
  hasCrypto: !!window.crypto,
  hasRandomUUID: !!window.crypto?.randomUUID,
  href: location.href,
})
```

Typical output on a VPS accessed by IP:

```
protocol:        "http:"
isSecureContext: false
hasCrypto:       true
hasRandomUUID:   false
href:            "http://46.225.80.55:5555/"
```

---

## Why this happens

This is **not** a Docker bug and **not** a Prisma server-side failure.

1. The Prisma Studio **frontend** (React, bundled in `studio.js`) calls `window.crypto.randomUUID()`.
2. Modern browsers only expose `randomUUID()` in a **[secure context](https://developer.mozilla.org/en-US/docs/Web/Security/Secure_Contexts)**:
   - `https://…` (any host, with valid or user-trusted TLS)
   - `http://localhost` and `http://127.0.0.1`
3. `http://<public-ip>:5555` is **not** a secure context → `isSecureContext: false` → `randomUUID` is unavailable → the UI crashes.

The server and database connection can be perfectly fine. Only the browser UI fails.

---

## What does NOT fix it

- Changing Docker environment variables
- Restarting the container
- Opening firewall ports
- Downgrading Prisma
- Using a different base image

There is no server-side workaround. The browser must run Studio in a secure context.

---

## Solutions

### 1. Traefik + HTTPS + basic auth (recommended for production)

Traefik terminates TLS so the browser sees `https://`. Basic auth protects access.

→ [vps-traefik.md](./vps-traefik.md)

### 2. SSH tunnel (no reverse proxy)

Bind Studio to `127.0.0.1` on the VPS and forward the port over SSH. You then open `http://localhost:5555` on your machine (secure context).

→ [vps-ssh-tunnel.md](./vps-ssh-tunnel.md)

### 3. Run Studio locally (no VPS container)

Point `DATABASE_URL` at the remote database and run on your PC:

```powershell
bun run studio
```

→ [local-development.md](./local-development.md)

---

## Summary

| Access URL | Secure context | Studio UI |
|------------|----------------|-----------|
| `http://localhost:5555` | Yes | Works |
| `http://127.0.0.1:5555` | Yes | Works |
| `https://studio.example.com` | Yes | Works |
| `http://<public-ip>:5555` | **No** | **Broken** |

See also: [deployment-overview.md](./deployment-overview.md) | [security.md](./security.md)
