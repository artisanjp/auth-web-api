# AUTHENTIK_SECRET_KEY shorter than Django's recommended length

- **Issue**: Django's system check reports `security.W009` on every core/worker start: the SECRET_KEY has fewer than 50 characters. The key was generated with `openssl rand -base64 32` (44 chars) per the README, so entropy is fine (256 bits) — only the length heuristic trips, but the warning adds noise to every boot log.
- **Location**: prod/dev env files (`AUTHENTIK_SECRET_KEY`); README setup instructions recommend `openssl rand -base64 32`
- **Severity**: Low — cryptographically the current key is strong; this is a lint-style warning, not a vulnerability.
- **Context**: Observed in worker/core startup logs during the 2025.10 → 2026.5 upgrade (2026-08-11), on both dev and prod.
- **Suggested Fix**: Manual — rotating the key logs out all sessions, so do it in a quiet window if at all: generate with `openssl rand -base64 48` (64 chars), update the env file, restart core/worker. Also update the README recommendation to `-base64 48` so future deployments don't trip the check.
