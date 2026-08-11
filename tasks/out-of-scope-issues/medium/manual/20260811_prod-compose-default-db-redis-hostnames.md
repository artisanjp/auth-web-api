# Prod compose relies on default `postgres` hostname

- **Issue**: `docker-compose.prod.yml` defaults `AUTHENTIK_POSTGRESQL__HOST` to `postgres`, but the hq-backbone container on `artisan-hq-network-01` is named `hq-postgres`. Prod works only if the prod env file overrides `POSTGRES_HOST` or a network alias exists. (An earlier version of this issue also flagged Redis: moot — Authentik 2026.x has no Redis dependency at all, and this stack already runs without one.)
- **Location**: `docker-compose.prod.yml` (`POSTGRES_HOST:-postgres` on core/worker)
- **Severity**: Medium — if the default is actually in use, a container rename or fresh deploy breaks auth; if the env file overrides it, the compose default is misleading.
- **Context**: Noticed while wiring the LDAP outpost's `AUTHENTIK_HOST` to the core container name (2026-08-11); Redis half retired during the 2026.5 upgrade planning.
- **Suggested Fix**: Manual — requires inspecting the prod env file on Shidenkai (secrets, cannot be read by the agent). Either set an explicit `hq-postgres` value (as compose default or documented env requirement) or document the network alias that makes the short name resolve.
