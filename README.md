# Betterlytics - Self-Hosted

Betterlytics is a modern, privacy-first analytics platform that provides powerful insights about your website traffic without compromising user privacy.
This repository provides everything you need to deploy Betterlytics on your own infrastructure using Docker.

## Quick Start

### 1. Configure

Run the interactive setup script to generate a `.env` file:

```bash
chmod +x setup.sh
./setup.sh
```

Or copy `.env.example` to `.env` and fill in the values manually.

### 2. Deploy

```bash
docker compose up -d --wait
```

### 3. Create the first account

Open your instance URL in a browser and create your account.

## Deployment Modes

### Standalone (automatic HTTPS, recommended for a public server)

The container is the public endpoint and provisions and renews its own Let's Encrypt certificate. This is the default in `setup.sh`.

Ports 80 and 443 must be reachable from the internet.

Configuring by hand? See [Standalone](https://betterlytics.io/docs/installation/self-hosting#standalone) in the Self-Hosting Guide.

## Upgrading

Each release bumps the image version in `docker-compose.yml`, so updating this
repository is what upgrades your instance:

```bash
git pull
docker compose up -d --wait
```

Compose pulls the new image on its own. Read the release notes first for
version-specific steps such as backups or disk space.

### Upgrading to PUBLIC_URL and TLS

`DOMAIN`, `HTTP_SCHEME`, `FORCE_HTTP_SCHEME` and `HTTPS_PORT` are replaced by
`PUBLIC_URL` and `TLS`. An instance whose `.env` still has only the old names
stops at start, and `docker compose logs betterlytics-init` prints the two lines
to add:

| Old `.env`                                       | New `.env`                                     |
| ------------------------------------------------ | ---------------------------------------------- |
| `HTTP_SCHEME=https`                              | `PUBLIC_URL=https://<DOMAIN>` and `TLS=auto`   |
| `HTTP_SCHEME=http`                               | `PUBLIC_URL=https://<DOMAIN>` and `TLS=off`    |
| `HTTP_SCHEME=http` with `FORCE_HTTP_SCHEME=http` | `PUBLIC_URL=http://<DOMAIN>` and `TLS=off`     |
| `HTTPS_PORT`                                     | Remove it. If your `docker-compose.override.yml` uses `${HTTPS_PORT}`, write `443` there first |

`HTTP_PORT` and `BIND_ADDRESS` keep their meaning. Then run `docker compose up -d --wait` again.

### Upgrading from v1.3.5 or earlier

This release includes one-time ClickHouse migrations that rewrite the events
table. Before upgrading:

- Ensure free disk space of at least 2–3× the size of your ClickHouse data
  volume (the events table is rewritten twice; space is reclaimed at the end).
- Expect a long first boot on large installations. Do not interrupt the
  `betterlytics-init` container while migrations run.
- Back up your ClickHouse and Postgres volumes first.

## Configuration Reference

| Variable                   | Description                                              | Default |
| -------------------------- | -------------------------------------------------------- | ------- |
| `PUBLIC_URL`               | Full address browsers use: scheme, host and, if non-standard, the port (`https://analytics.example.com`, `https://host:8443`). No path. Logins, links and the tracking snippet use exactly this address |         |
| `TLS`                      | `auto` for built-in Let's Encrypt (needs an `https://` `PUBLIC_URL` with a public hostname and no port), `off` for plain HTTP behind your own proxy or locally | `off`   |
| `SESSION_REPLAYS_ENABLED`  | Enable Session Replay                                    | `true`  |
| `REPLAY_RETENTION_DAYS`    | Days to keep session replays, `-1` for indefinitely      | `60`    |
| `SSL_EMAIL`                | Optional email for the Let's Encrypt account             |         |
| `ACME_CA`                  | Optional ACME directory URL (e.g. Let's Encrypt staging) |         |
| `SECRET_BASE`              | Single secret all passwords and auth keys derive from; at least 32 random characters. An empty value, `CHANGEME` or a shorter one logs a warning at every start |         |
| `ENABLE_EMAILS`            | Enable sending emails                                    | `false` |
| `MAILER_SEND_API_TOKEN`    | MailerSend API token (no SMTP server config needed if set) |       |
| `SMTP_HOST`                | SMTP server hostname                                     |         |
| `SMTP_PORT`                | SMTP server port                                         |         |
| `SMTP_USER`                | SMTP username                                            |         |
| `SMTP_PASSWORD`            | SMTP password                                            |         |
| `SMTP_FROM`                | Sender for all outgoing mail, `Name <address>` or a bare address. Required when `ENABLE_EMAILS=true` (SMTP and MailerSend) |         |
| `ENABLE_GEOLOCATION`       | Enable IP geolocation (requires MaxMind)                 | `false` |
| `MAXMIND_ACCOUNT_ID`       | MaxMind account ID                                       |         |
| `MAXMIND_LICENSE_KEY`      | MaxMind license key                                      |         |
| `GEOLOCATION_MODE`         | `country` (~9 MB DB) or `full` for city/region (~61 MB)  | `country` |
| `ENABLE_ASN_LOOKUP`        | Visitor network (ASN) lookup for bot detection, needs the MaxMind credentials | `false` |
| `BACKGROUND_JOBS_ENABLED`  | Background worker: all outgoing email and data-retention cleanup; `false` stops both | `true`  |
| `PUBLIC_ENABLE_FAVICON_FETCHING` | Fetch site icons from DuckDuckGo (server-side); `false` stops these requests | `true`  |
| `LOG_LEVEL`                | Backend log level: `error`, `warn`, `info`, `debug`, `trace` | `info`  |
| `PUSHOVER_APP_TOKEN`       | Pushover app token for uptime alert integrations         |         |
| `ALLOW_PRIVATE_TARGETS`    | Monitors and webhooks may reach private/LAN addresses on any port. Loopback and link-local are always blocked; reach services on the Docker host through its LAN IP or `host.docker.internal` | `true`  |
| `HTTP_PORT`                | Advanced: exposed HTTP port, must be `80` with `TLS=auto` | `5566`  |
| `BIND_ADDRESS`             | Advanced: host address to bind the exposed ports to      | `127.0.0.1` |
| `TRUSTED_PROXIES`          | Extra proxy IPs/CIDRs whose `X-Forwarded-For` is trusted |         |
| `AUTH_TRUSTED_PROXIES`     | Behind your own proxy: the IPs/CIDRs it connects from, so sign-in rate limits apply per visitor |         |

All database passwords and auth secrets are derived automatically from `SECRET_BASE`. You only need to set one secret. Use at least 32 random characters (`setup.sh` generates 64, or use `openssl rand -hex 32`) and set it before the first start: the databases are created with passwords derived from it, so changing it later locks the app out of existing data. If `docker compose logs betterlytics-selfhost` shows a `SECRET_BASE` warning on an instance that holds no data yet, run `docker compose down -v`, set a new value and start again.

### Behind a Reverse Proxy

Set `TLS=off` and bind to localhost on a non-standard port so you don't expose port 80 directly:

```
PUBLIC_URL=https://analytics.example.com
TLS=off
BIND_ADDRESS=127.0.0.1
HTTP_PORT=5566
```

Then point your reverse proxy to that port. The built-in Caddy configuration ships inside the image; to change it, mount your own configuration directory over `/etc/caddy` in `docker-compose.override.yml`. Proxies on the same host or a private network are trusted automatically. If your proxy connects from a public address, list it in `TRUSTED_PROXIES`, otherwise every visitor is recorded with the proxy's IP. To check, compare `request.remote_ip` and `request.client_ip` in `docker compose logs betterlytics-selfhost`.

Example with **Caddy**:

```
analytics.example.com {
    reverse_proxy 127.0.0.1:5566
}
```

Example with **NGINX**:

```nginx
server {
    listen 443 ssl;
    server_name analytics.example.com;

    ssl_certificate     /etc/letsencrypt/live/analytics.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/analytics.example.com/privkey.pem;

    # Session replay uploads are up to 6 MB; nginx's 1 MB default returns 413 and stops recording.
    client_max_body_size 6m;

    location / {
        proxy_pass http://127.0.0.1:5566;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Serving a status page on its own domain? See [Custom status page domains](https://betterlytics.io/docs/installation/self-hosting#custom-status-page-domains) in the Self-Hosting Guide.

### Plain HTTP or IP access

Betterlytics accepts logins only from the exact URL it is configured for, its `PUBLIC_URL`. Your proxy must serve it over HTTPS at that address, including the port if it is not 443. If browsers reach the instance over plain HTTP (an IP address or an internal hostname on a trusted network), edit `.env` by hand:

```
PUBLIC_URL=http://192.168.1.10:5566
TLS=off
BIND_ADDRESS=0.0.0.0
```

`PUBLIC_URL` must include the port browsers use unless it is 80. Then run `docker compose up -d --wait`. Passwords and session cookies then travel unencrypted, so do this only on a network you trust. If the URL doesn't match, the sign-in page says the address doesn't match the configured one, and `docker compose logs betterlytics-selfhost` shows `[Better Auth]: Invalid origin: <origin>`.

## Requirements

- Docker Engine 25+ and Docker Compose v2.24+. The image's healthcheck start interval needs Engine 25 ([details](https://betterlytics.io/docs/installation/self-hosting#requirements))
- An x86_64 (amd64) server. The image is not published for ARM (arm64), so ARM hosts fail with "no matching manifest"
- A domain name pointed to your server
- Ports 80/443 open (standalone mode) or a reverse proxy configured

## Documentation

For detailed instructions, advanced configuration, and troubleshooting, see the [Self-Hosting Guide](https://betterlytics.io/docs/installation/self-hosting).
