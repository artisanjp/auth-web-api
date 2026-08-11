# auth-web-api

Artisan internal central authentication API, built on [Authentik](https://goauthentik.io/).

## Services

### Development

| Service | Container | Description |
|---|---|---|
| PostgreSQL | `artisan-auth-postgres` | Database for Authentik |
| Authentik Server | `artisan-auth-core` | Authentik authentication server |
| Authentik Worker | `artisan-auth-worker` | Background task worker |
| Nginx | `artisan-auth-nginx` | Reverse proxy (HTTP->HTTPS, TLS termination) |
| Mailpit | `artisan-auth-mailpit` | Local SMTP + email UI (dev only) |

### Production

| Service | Container | Description |
|---|---|---|
| Authentik Server | `artisan-auth-core` | Authentik authentication server |
| Authentik Worker | `artisan-auth-worker` | Background task worker |
| Authentik LDAP Outpost | `artisan-auth-ldap` | LDAP/LDAPS endpoint (host ports 389/636) |

Production uses an external PostgreSQL (`postgres` on `artisan-hq-network-01`), external Postfix relay, and Traefik for TLS termination and routing. See [TRAEFIK.md](TRAEFIK.md) for details.

## Prerequisites

- Docker and Docker Compose
- OpenSSL (for dev certificate generation)

## Development Setup

### 1. Configure environment

```bash
cp .env.example .env
```

Edit `.env` and fill in the required values:

- `AUTHENTIK_TAG` -- the Authentik version to run (required, no default; see [Upgrading Authentik](#upgrading-authentik))
- `AUTHENTIK_SECRET_KEY` -- generate with `openssl rand -base64 32`
- `POSTGRES_PASSWORD` -- generate with `openssl rand -base64 24`

### 2. Generate TLS certificates

```bash
./scripts/makecert [domain]
```

Generates self-signed certificates in `certs/` for local HTTPS. Defaults to `auth.artisan-tools.com`.

### 3. Start services

```bash
./scripts/up dev all
```

Authentik will be available at `https://localhost` (or `https://localhost:<port>` if `APP_PORT_HTTPS` is set).

Mailpit web UI is available at `http://localhost:8025`.

## Production Deployment

### Prerequisites

- DNS: `auth.artisan-tools.com` pointing to server IP
- Docker network `artisan-hq-network-01` exists with `postgres` and `postfix` containers
- Traefik running on the same host with Docker provider enabled (see [TRAEFIK.md](TRAEFIK.md))

### 1. Configure environment

```bash
cp .env.example .env
```

Edit `.env` with production values:

- `AUTHENTIK_TAG` -- the Authentik version to run (required, no default; see [Upgrading Authentik](#upgrading-authentik))
- `AUTHENTIK_SECRET_KEY` -- generate with `openssl rand -base64 32`
- `POSTGRES_HOST=postgres` (external container on artisan-hq-network-01)
- `POSTGRES_PASSWORD` -- the external postgres password
- Uncomment the production SMTP section (`SMTP_HOST=postfix`, `SMTP_PORT=25`)

### 2. Stop dev containers (if running)

```bash
./scripts/down dev all
```

### 3. Start all services

```bash
./scripts/up prod all
```

### 4. Verify

```bash
curl -I https://auth.artisan-tools.com
docker exec artisan-auth-core ak healthcheck
```

### 5. LDAP outpost (optional)

The `ldap` service (prod only) exposes Authentik as an LDAP/LDAPS directory on host ports 389/636. Its image tag **must always match** the core/worker tag — mismatched core/outpost versions are unsupported and can fail in non-obvious ways (the admin UI's outpost health panel shows version mismatches) — so upgrade all three together.

Bootstrap order (the outpost needs an API token that only exists after the outpost is created in Authentik):

1. In the Authentik admin UI (`https://auth.artisan-tools.com`): create an **LDAP Provider** (set Base DN, e.g. `dc=ldap,dc=goauthentik,dc=io`, and a bind flow), an **Application** bound to it, and an **Outpost** of type LDAP referencing that application. Set the outpost's **Integration** to `----` (none) — this deployment is managed by compose; selecting Docker would make Authentik try to spawn its own duplicate container.
2. Copy the outpost's token (**Outposts → click the outpost → View deployment info**) into `AUTHENTIK_LDAP_TOKEN` in `.env`.
3. Start it: `./scripts/up prod ldap`
4. Verify: `./scripts/logs prod ldap` shows a successful websocket connection to core (no 403s), and `ss -tlnp | grep -E ':(389|636)\b'` shows both ports bound. Then do a real bind, e.g. `ldapsearch -x -H ldap://<host> -D "cn=<user>,ou=users,<base-dn>" -w <pass> -b "<base-dn>"`.

> **LDAPS note:** port 636 is published, but LDAPS only actually works once a **Certificate** (and TLS Server Name) is set on the LDAP provider. Until then the socket accepts TCP connections and every TLS handshake fails — a bound port is not proof of working LDAPS. Plain LDAP on 389 works immediately (LAN only; credentials travel unencrypted).

The outpost is stateless (no volumes) and pulls all config from the Authentik API over the internal Docker network — it is **not** routed through Traefik.

> **Firewall note:** Docker-published ports bypass ufw INPUT rules, and the `DOCKER-USER` chain sees packets **after DNAT** — so rules there must match the container-side ports `3389`/`6636` (or use `-m conntrack --ctorigdstport 389`/`636`), not 389/636. Example: allow tcp dport 3389/6636 from `192.168.100.0/24`, drop other sources, in `DOCKER-USER`. Binding the ports to the LAN IP in the compose file (`192.168.100.71:389:3389`) limits which interface listens but is **not** a source-subnet ACL.

## Scripts

All scripts require an environment as the first argument: `dev` or `prod`.

| Script | Description |
|---|---|
| `scripts/up <dev\|prod> <service\|all>` | Start containers |
| `scripts/down <dev\|prod> <service\|all>` | Stop containers |
| `scripts/restart <dev\|prod> <service\|all>` | Restart containers |
| `scripts/build <dev\|prod> <service\|all>` | Build images |
| `scripts/logs <dev\|prod> <service\|all> [options]` | View container logs |
| `scripts/reset <dev\|prod> <volume\|all>` | Remove volumes (destructive) |
| `scripts/makecert [domain]` | Generate self-signed TLS certificates (dev) |
| `scripts/help` | Show help |

### Service Aliases

| Alias | Maps To | Notes |
|---|---|---|
| `auth` | `core` | Authentik server |
| `db` | `postgres` | Dev only |
| `mail` | `mailpit` | Dev only |
| `ldap` | `ldap` | Direct name, prod only (LDAP outpost) |
| `all` | env-dependent | Dev: all 5 services; Prod: core + worker + ldap |

## Upgrading Authentik

The version is pinned by `AUTHENTIK_TAG` in `.env` — one variable shared by `core`, `worker`, and the `ldap` outpost so they can never run different versions. Compose refuses every command until it is set.

Rules:

1. **Upgrade sequentially, one release at a time** (e.g. `2025.10 → 2025.12 → 2026.2 → 2026.5`). Never skip releases — migrations assume the previous release's schema.
2. Per hop: bump `AUTHENTIK_TAG` in `.env` → `docker compose -f docker-compose.<env>.yml pull core worker` → `./scripts/up <env> core worker` → watch `./scripts/logs <env> core` until migrations finish → `docker exec artisan-auth-core ak healthcheck` → log in via the UI. Only proceed to the next hop when healthy.
3. **Back up the database first** (prod: dump the authentik DB on the external postgres before the first hop).
4. Keep hops scoped to `core worker`. If the `ldap` outpost is running, **stop it before the first hop** (`./scripts/down <env> ldap`) and start it again only once the final version is reached — a running outpost on the old version violates the server/outpost version-match requirement mid-upgrade.
5. Read the upstream release notes for every hop: <https://docs.goauthentik.io/releases/>. Known one-time steps: 2025.12 requires unique group names (pre-check: `SELECT name, count(*) FROM authentik_core_group GROUP BY name HAVING count(*) > 1;`), moves storage from `/media` to `/data` — this repo's compose and the git-tracked `data/media/public/` layout already reflect it, but any **untracked runtime uploads** still under `./media` on a deployment host must be merged once, with the stack stopped, after pulling: `mkdir -p data/media && if [ -d media ]; then cp -a media/. data/media/ && rm -rf media; fi` (preserves ownership/permissions via `cp -a`) — and it changes file serving to signed `/files/...` URLs with picker paths relative to `/data/media/public/` — re-enter the Brand asset fields (see Custom Branding) right after that hop and verify the icons render. 2026.5 switches the default listen address to `[::]`; see the fallback note in `.env.example` if the host has IPv6 disabled.

## Custom Branding

Place brand assets in `data/media/public/custom/`. The `./data` directory is bind-mounted into the Authentik containers at `/data`; the file picker only sees files under `/data/media/public/`. Since 2025.12, authentik serves these files via short-lived signed `/files/...` URLs — there is no fixed public URL you can hit directly; verify by checking that the assets render in the UI.

Current assets:

| File | Purpose |
|---|---|
| `data/media/public/custom/icon.png` | Brand icon (favicon, app icon) |
| `data/media/public/custom/icon_left_brand.svg` | Logo shown in the top-left of the UI |
| `data/media/public/custom/flow_background.png` | Background image for login/flow pages |

To apply, go to **Admin → System → Brands**, edit the brand, and set the fields to paths **relative to `/data/media/public/`, without a leading slash**:

| Field | Value |
|---|---|
| Favicon | `custom/icon.png` |
| Logo | `custom/icon_left_brand.svg` |
| Flow background | `custom/flow_background.png` |

Changes to files in the bind mount are visible to the containers immediately — no restart needed.

### Changing the welcome message

The "Welcome to authentik!" text on the sign-in page is the **flow title**, not a brand setting. To change it:

1. Go to **Admin → Flows and Stages → Flows**
2. Edit the **default-authentication-flow** (or whichever flow is used for login)
3. Change the **Title** field to your desired message
4. Click **Update**

Repeat for any other flows that display a welcome message (e.g., enrollment, recovery).

## Environment Variables

See `.env.example` for all options with descriptions.

| Variable | Description |
|---|---|
| `AUTHENTIK_TAG` | Authentik version tag, shared by core/worker/ldap (required, no default) |
| `AUTHENTIK_IMAGE` | Server image registry override (default: `ghcr.io/goauthentik/server`) |
| `AUTHENTIK_SECRET_KEY` | Secret key for Authentik (required) |
| `AUTHENTIK_LDAP_TOKEN` | API token for the LDAP outpost, prod only (see LDAP outpost section) |
| `APP_PORT_HTTP` | HTTP port, dev only (default: `80`) |
| `APP_PORT_HTTPS` | HTTPS port, dev only (default: `443`) |
| `POSTGRES_HOST` | PostgreSQL hostname (default: `postgres`) |
| `POSTGRES_USER` | PostgreSQL username (default: `authentik`) |
| `POSTGRES_PASSWORD` | PostgreSQL password (required) |
| `POSTGRES_DB` | PostgreSQL database name (default: `authentik`) |
| `SMTP_HOST` | SMTP server host |
| `SMTP_PORT` | SMTP server port |
| `SMTP_USERNAME` | SMTP username |
| `SMTP_PASSWORD` | SMTP password |
| `SMTP_USE_TLS` | Enable STARTTLS (default: `false`) |
| `SMTP_USE_SSL` | Enable SMTPS (default: `false`) |
| `SMTP_FROM` | From address for outgoing email |
