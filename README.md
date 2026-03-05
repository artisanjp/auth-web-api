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
| `all` | env-dependent | Dev: all 5 services; Prod: core + worker |

## Environment Variables

See `.env.example` for all options with descriptions.

| Variable | Description |
|---|---|
| `AUTHENTIK_SECRET_KEY` | Secret key for Authentik (required) |
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
