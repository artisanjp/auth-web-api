# LDAPS (port 636) published but no certificate configured on the LDAP provider

- **Issue**: The new `ldap` outpost publishes host port 636 (LDAPS), but LDAPS only works once a **Certificate** and **TLS Server Name** are set on the LDAP provider in Authentik. Until then the socket accepts TCP connections and every TLS handshake fails, and plain LDAP on 389 carries bind credentials unencrypted across the LAN.
- **Location**: `docker-compose.prod.yml` (`ldap` service, `"636:6636"`); Authentik admin UI → LDAP Provider (no cert yet)
- **Severity**: Medium — credentials in cleartext on the office LAN until TLS is configured; port 636 gives a false sense of security if clients aren't tested.
- **Context**: Deliberate deferral per the user's spec ("publish now even though TLS comes later") while adding the LDAP outpost (2026-08-11). Documented in README's LDAPS note.
- **Suggested Fix**: Manual — on prod Authentik admin UI: create/assign a certificate (e.g. the `*.artisan-tools.com` wildcard or a dedicated cert) plus TLS Server Name on the LDAP provider, then verify with `ldapsearch -H ldaps://192.168.100.71 ...` and switch LAN clients to 636.
