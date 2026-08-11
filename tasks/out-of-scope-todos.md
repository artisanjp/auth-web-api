# Out-of-Scope TODOs

## 1. `mailpit` port collision with the shipping-production-manager stack

- **Issue**: `artisan-auth-mailpit` cannot start — `Bind for 127.0.0.1:1025 failed: port is already allocated`. The long-running `shipping-production-manager-mailpit` container already holds `127.0.0.1:1025` (SMTP) and `127.0.0.1:8025` (web UI). Both stacks hardcode the same host ports. Because this failure aborts `docker compose up` partway through, it also left `artisan-auth-nginx` created-but-never-started, which is what took the server offline.
- **Location**: `docker-compose.dev.yml:99-107` (mailpit service, `ports:` block)
- **Severity**: Medium — auth stack works without mailpit, but any `docker compose up` on this host aborts mid-start and can silently leave nginx down again.
- **Context**: Found while investigating why the auth server was unreachable.
- **Suggested Fix**: Make the host ports overridable and non-colliding, e.g. `"${MAILPIT_UI_PORT:-8026}:8025"` / `"${MAILPIT_SMTP_PORT:-1026}:1025"`, matching the `APP_PORT_HTTP`/`APP_PORT_HTTPS` pattern already used by the nginx service. Alternatively drop the host port publishing entirely if mailpit is only consumed over the internal `artisan-auth-network`.

## 2. Deprecated `listen ... http2` directive in nginx config

- **Issue**: nginx logs a startup warning on every boot: `the "listen ... http2" directive is deprecated, use the "http2" directive instead`.
- **Location**: `docker/authentik/files/nginx/nginx.conf:46`
- **Severity**: Low — warning only today, but the directive is slated for removal in a future nginx release, which would then fail the config.
- **Context**: Seen in `docker logs artisan-auth-nginx` while confirming nginx came up healthy.
- **Suggested Fix**: Change `listen 443 ssl http2;` to `listen 443 ssl;` plus a separate `http2 on;` line in the same `server` block.

> Newer issues are tracked as individual files under `tasks/out-of-scope-issues/<priority>/`.
