# LDAPS (port 636) published but no certificate configured on the LDAP provider

- **Issue**: The new `ldap` outpost publishes host port 636 (LDAPS), but LDAPS only works once a **Certificate** and **TLS Server Name** are set on the LDAP provider in Authentik. Until then the socket accepts TCP connections and every TLS handshake fails, and plain LDAP on 389 carries bind credentials unencrypted across the LAN.
- **Location**: `docker-compose.prod.yml` (`ldap` service, `"636:6636"`); Authentik admin UI → LDAP Provider (no cert yet)
- **Severity**: Medium — credentials in cleartext on the office LAN until TLS is configured; port 636 gives a false sense of security if clients aren't tested.
- **Context**: Deliberate deferral per the user's spec ("publish now even though TLS comes later") while adding the LDAP outpost (2026-08-11). Documented in README's LDAPS note.
- **Suggested Fix**: Manual — use Authentik **certificate discovery** with the auto-renewing wildcard cert from hq-backbone's Traefik certbot sidecar (investigated 2026-08-11, deferred by user):
  1. Mount the sidecar's output dir into the worker at a named subpath: `.../hq-backbone/servers/traefik/certs` → `/certs/artisan-tools.com:ro` (certbot layout `fullchain.pem`/`privkey.pem`; discovery names the keypair after the folder and re-scans on a schedule, so renewals propagate automatically; the LDAP outpost picks up cert updates via websocket).
  2. **Blocker to solve first**: `privkey.pem` is written `root:root` mode `600` by the sidecar — the non-root Authentik worker cannot read it. Needs a small hq-backbone change (e.g. sidecar copies with group-readable perms for a shared GID); note perms are reset on every renewal copy, so a one-off host `chmod` is NOT durable.
  3. Admin UI: LDAP provider → Certificate = discovered pair, TLS Server Name = `auth.artisan-tools.com` (wildcard-covered, resolves to 192.168.100.71 on LAN).
  4. Clients switch to `ldaps://auth.artisan-tools.com:636` (hostname, not IP); verify with `ldapsearch -H ldaps://auth.artisan-tools.com ...`; consider closing 389 afterwards.
