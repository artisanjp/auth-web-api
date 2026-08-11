# Traefik Integration

Production uses Traefik as the reverse proxy and TLS terminator. Traefik runs separately (on the `artisan-hq-network-01` Docker network) and routes traffic to this service via Docker labels.

## Prerequisites

1. **Traefik running** on the same Docker host with Docker provider enabled
2. **External network** `artisan-hq-network-01` exists:
   ```bash
   docker network create artisan-hq-network-01
   ```
3. **Wildcard TLS certificate** for `*.artisan-tools.com` configured in Traefik
4. **DNS** `auth.artisan-tools.com` pointing to the Traefik host

## How It Works

The `core` service in `docker-compose.prod.yml` has Traefik labels that:
- Enable Traefik discovery (`traefik.enable=true`)
- Route `auth.artisan-tools.com` traffic to port 9000 (Authentik's internal HTTP port)
- Use the `websecure` entrypoint (HTTPS/443) with TLS enabled
- Specify the Docker network for Traefik to connect on

The `worker` service has `traefik.enable=false` to prevent accidental exposure.

## Security Headers Middleware

Traefik should have a shared security headers middleware applied. If not already configured globally, you can add it via labels on the `core` service:

```yaml
labels:
  - "traefik.http.middlewares.auth-security-headers.headers.stsSeconds=31536000"
  - "traefik.http.middlewares.auth-security-headers.headers.stsIncludeSubdomains=true"
  - "traefik.http.middlewares.auth-security-headers.headers.stsPreload=true"
  - "traefik.http.middlewares.auth-security-headers.headers.frameDeny=true"
  - "traefik.http.middlewares.auth-security-headers.headers.contentTypeNosniff=true"
  - "traefik.http.middlewares.auth-security-headers.headers.browserXssFilter=true"
  - "traefik.http.middlewares.auth-security-headers.headers.referrerPolicy=strict-origin-when-cross-origin"
  - "traefik.http.routers.auth-web-api.middlewares=auth-security-headers"
```

If Traefik already has a global `security-headers` middleware, reference it instead:

```yaml
labels:
  - "traefik.http.routers.auth-web-api.middlewares=security-headers@file"
```

## WebSocket Support

Traefik handles WebSocket connections automatically -- no additional configuration needed. Authentik uses WebSockets for real-time UI updates and they will work out of the box.

## Custom Middleware via Labels

To add additional middleware (e.g., rate limiting, IP allowlisting):

```yaml
labels:
  # Rate limiting example
  - "traefik.http.middlewares.auth-ratelimit.ratelimit.average=100"
  - "traefik.http.middlewares.auth-ratelimit.ratelimit.burst=50"
  - "traefik.http.routers.auth-web-api.middlewares=auth-ratelimit"

  # IP allowlist example
  - "traefik.http.middlewares.auth-ipallow.ipallowlist.sourcerange=10.0.0.0/8"
  - "traefik.http.routers.auth-web-api.middlewares=auth-ipallow"

  # Multiple middleware (comma-separated)
  - "traefik.http.routers.auth-web-api.middlewares=auth-security-headers,auth-ratelimit"
```

## Network Architecture

```
Internet -> Traefik (TLS termination, port 443)
              |
              v
         artisan-hq-network-01 (shared Docker network)
              |
              +-- artisan-auth-core (port 9000, HTTP)
              +-- artisan-auth-worker (no HTTP, background tasks)
              +-- artisan-auth-ldap (host ports 389/636 -> 3389/6636, NOT via Traefik)
              +-- postgres (external database)
              +-- postfix (external SMTP relay)
```

## Troubleshooting

**Service not accessible:**
```bash
# Check Traefik can see the container
docker inspect artisan-auth-core --format '{{json .Config.Labels}}' | jq .

# Check the container is on the correct network
docker inspect artisan-auth-core --format '{{json .NetworkSettings.Networks}}' | jq .

# Check Traefik's dashboard for the router/service
curl -s http://localhost:8080/api/http/routers | jq '.[] | select(.name | contains("auth"))'
```

**Container healthy but Traefik returns 502:**
- Verify port 9000 is correct: `docker exec artisan-auth-core curl -s http://localhost:9000/-/health/`
- Verify `traefik.docker.network` label matches the actual network name
