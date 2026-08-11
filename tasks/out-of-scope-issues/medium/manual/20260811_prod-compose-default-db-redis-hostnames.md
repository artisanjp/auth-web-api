# Prod compose relies on default `postgres`/`redis` hostnames

- **Issue**: `docker-compose.prod.yml` defaults `AUTHENTIK_POSTGRESQL__HOST` to `postgres` and sets no `AUTHENTIK_REDIS__HOST` (Authentik's default is `redis`), but the hq-backbone containers on `artisan-hq-network-01` are named `hq-postgres` and `hq-redis`. Prod works only if the prod env file overrides `POSTGRES_HOST` and Authentik's Redis host is configured somewhere, or network aliases exist.
- **Location**: `docker-compose.prod.yml:10` (`POSTGRES_HOST:-postgres`); absence of any `AUTHENTIK_REDIS__*` keys
- **Severity**: Medium — if the defaults are actually in use, a container rename or fresh deploy breaks auth; if the env file overrides them, the compose defaults are misleading.
- **Context**: Noticed while wiring the LDAP outpost's `AUTHENTIK_HOST` to the core container name (2026-08-11).
- **Suggested Fix**: Manual — requires inspecting the prod env file on Shidenkai (secrets, cannot be read by the agent). Either set explicit `hq-postgres`/`hq-redis` values (as compose defaults or documented env requirements) or document the network aliases that make the short names resolve.
