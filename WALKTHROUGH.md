# Authelia Setup Verification

## Overview
We have set up **Authelia** with Docker Compose, **Nginx** (SSL/HTTPS), and a file-based user database. The setup is configured for `localhost.artisan-jp.com`.

## Validation Steps
1.  **Host Entry**: Ensure `localhost.artisan-jp.com` maps to `127.0.0.1` in your hosts file (or use `curl`'s resolver as tested).
2.  **Start Services**: `docker compose up -d`
3.  **Check Status**: `docker compose ps` should show healthy services.
4.  **Health Check**:
    ```bash
    curl -k -I https://localhost.artisan-jp.com/api/health
    ```
    Should return `HTTP/1.1 200 OK`.

## Configuration Files
- `.env`: Controls `HOST` (`localhost.artisan-jp.com`), `PUBLIC_PORT` (`443`), `USE_SMTP`.
- `docker-compose.yml`: Maps port 443 and mounts certificates.
- `docker/authelia/files/config/configuration.yml`: Authelia config (HTTPS enabled).
- `docker/nginx/files/conf.d/default.conf`: Nginx SSL config.
- `certs/`: Contains `cert.pem` and `key.pem` (Self-signed).

## Backup Strategy
- **Backup**: Archive the entire `/data` directory.
    - `users.yml` (Users)
    - `db.sqlite3` (Sessions/2FA)

## SMTP
- To enable SMTP, set `USE_SMTP=true` in `.env` and restart.
