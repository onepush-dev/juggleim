# JuggleIM on Railway

[JuggleIM](https://github.com/juggleim/im-server) (Apache-2.0) — a self-hosted, multi-tenant instant-messaging server: WebSocket long connections for client SDKs (Web, iOS, Android, Flutter, uni-app), a signed server-side REST API for your backend, private/group chat, chatrooms, message history, push and a built-in admin console. Deploy it on Railway with one click.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/S1gZNN)

## What this template runs

- **juggleim**: `ghcr.io/onepush-dev/juggleim:c01fa24`, upstream `juggleim/im-server` built from source at commit `c01fa24` (binary unmodified). A Caddy front door on port 8080 routes one public HTTPS domain to the four internal listeners:
  - `/im`, `/imbot`, `/health` → WebSocket long connections (9003)
  - `/apigateway/*` → server-side API (9001)
  - `/navigator/*` → navigator (9002)
  - everything else → admin console and `/admingateway/*` (8090)
- **mysql**: `mysql:8.0` with a volume at `/var/lib/mysql` (users, groups, messages, apps), private network only.

On first boot the start script creates the schema, replaces the upstream default `admin/123456` with a generated password, sets a per-deploy admin JWT secret and registers the public domain as the WSS connect address handed to SDKs.

## Variables

| Service | Variable | Value | Notes |
|---|---|---|---|
| juggleim | `JUGGLEIM_ADMIN_PASSWORD` | generated secret | Password of the console user `admin`. |
| juggleim | `JUGGLEIM_ADMIN_SECRET` | generated secret | Signs admin console sessions (upstream falls back to a public default key without it). |
| juggleim | `JUGGLEIM_PUBLIC_DOMAIN` | `${{RAILWAY_PUBLIC_DOMAIN}}` | Address the navigator hands to client SDKs. Change it if you add a custom domain. |
| juggleim | `MYSQL_HOST` | `${{mysql.RAILWAY_PRIVATE_DOMAIN}}` | MySQL host on the private network. |
| juggleim | `MYSQL_PASSWORD` | `${{mysql.MYSQL_ROOT_PASSWORD}}` | MySQL password. |
| mysql | `MYSQL_ROOT_PASSWORD` | generated secret | MySQL root password. |

## How to use

1. Deploy, open the domain and sign in as `admin` with `JUGGLEIM_ADMIN_PASSWORD`.
2. Create an app (tenant) in the console; note its `app_key` and `app_secret`.
3. Your backend calls `https://<domain>/apigateway/...` with headers `appkey`, `nonce`, `timestamp`, `signature = sha1(app_secret + nonce + timestamp)`, e.g. `POST /apigateway/users/register` to get a user token.
4. Client SDKs connect with the app key and user token; point them at `wss://<domain>` (the navigator at `https://<domain>/navigator/general` returns the same address).

## Notes

- Connection logs (leveldb) live in the container and reset on redeploy; all chat data is in MySQL.
- Not affiliated with JuggleIM.
