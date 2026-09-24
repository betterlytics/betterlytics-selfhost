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

Open `/signup` on your instance in a browser, for example `https://analytics.example.com/signup` (`setup.sh` prints the exact URL), and create an account. On a fresh install the first account becomes the instance admin, even though open registration is disabled. Create it before sharing the URL, since until then anyone who can reach the instance can claim it.

Once an account exists, sign in at `/signin`; `/signup` only accepts invited users. `setup.sh` never creates, changes, or resets accounts.

## Deployment Modes

### Standalone (automatic HTTPS, recommended for a public server)

Set `HTTP_SCHEME=https`; `setup.sh` selects this mode by default. The container will automatically provision and renew TLS certificates via Let's Encrypt.
`HTTP_PORT` must be `80` and port 443 must be mapped; the container refuses to start otherwise.
Custom status-page domains get their certificate on first visit. If a visitor sees a TLS error, `docker compose logs betterlytics-selfhost | grep permission` shows the hostname and the status the `ask` endpoint answered (`404` not published or unknown, `403` reserved name, `429` lookup ceiling).

Ports 80 and 443 must be accessible from the internet for ACME challenges and HTTPS traffic. When using `setup.sh`, this is handled automatically, the script generates a `docker-compose.override.yml` that exposes port 443 and binds to `0.0.0.0`.

## Upgrading

Each release bumps the image version in `docker-compose.yml`, so updating this
repository is what upgrades your instance:

```bash
git pull
docker compose up -d --wait
```

Compose pulls the new image on its own. Read the release notes first for
version-specific steps such as backups or disk space.

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
| `DOMAIN`                   | Domain where your instance is accessible (no protocol)   |         |
| `SESSION_REPLAYS_ENABLED`  | Enable Session Replay                                    | `true`  |
| `REPLAY_RETENTION_DAYS`    | Days to keep session replays, `-1` for indefinitely      | `60`    |
| `HTTP_SCHEME`              | `http` or `https`, built-in Let's Encrypt when `https`   | `http`  |
| `SSL_EMAIL`                | Optional email for the Let's Encrypt account             |         |
| `ACME_CA`                  | Optional ACME directory URL (e.g. Let's Encrypt staging) |         |
| `SECRET_BASE`              | Single secret used to derive all passwords and auth keys |         |
| `DEFAULT_LANGUAGE`         | Default UI language                                      | `en`    |
| `ENABLE_EMAILS`            | Enable sending emails                                    | `false` |
| `MAILER_SEND_API_TOKEN`    | MailerSend API token (no SMTP config needed if set)      |         |
| `SMTP_HOST`                | SMTP server hostname                                     |         |
| `SMTP_PORT`                | SMTP server port                                         |         |
| `SMTP_USER`                | SMTP username                                            |         |
| `SMTP_PASSWORD`            | SMTP password                                            |         |
| `SMTP_FROM`                | Sender email address for outgoing mail                   |         |
| `ENABLE_GEOLOCATION`       | Enable IP geolocation (requires MaxMind)                 | `false` |
| `MAXMIND_ACCOUNT_ID`       | MaxMind account ID                                       |         |
| `MAXMIND_LICENSE_KEY`      | MaxMind license key                                      |         |
| `GEOLOCATION_MODE`         | `country` (~9 MB DB) or `full` for city/region (~61 MB)  | `country` |
| `BACKGROUND_JOBS_ENABLED`  | Email reports and data-retention cleanup                 | `true`  |
| `PUSHOVER_APP_TOKEN`       | Pushover app token for uptime alert integrations         |         |
| `HTTP_PORT`                | Exposed HTTP port, must be `80` when `HTTP_SCHEME=https` | `5566`  |
| `HTTPS_PORT`               | Exposed HTTPS port (mapped by `setup.sh` Standalone)     | `443`   |
| `BIND_ADDRESS`             | Host address to bind the exposed ports to                | `127.0.0.1` |
| `TRUSTED_PROXIES`          | Extra proxy IPs/CIDRs whose `X-Forwarded-For` is trusted |         |

All database passwords and auth secrets are derived automatically from `SECRET_BASE`. You only need to set one secret.

### Behind a Reverse Proxy

Set `HTTP_SCHEME=http` and bind to localhost on a non-standard port so you don't expose port 80 directly:

```
HTTP_SCHEME=http
BIND_ADDRESS=127.0.0.1
HTTP_PORT=5566
```

Then point your reverse proxy to that port. Proxies on the same host or a private network are trusted automatically. If your proxy connects from a public address, list it in `TRUSTED_PROXIES`, otherwise every visitor is recorded with the proxy's IP. To check, compare `request.remote_ip` and `request.client_ip` in `docker compose logs betterlytics-selfhost`.

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

## Requirements

- Docker and Docker Compose
- A domain name pointed to your server
- Ports 80/443 open (standalone mode) or a reverse proxy configured

## Documentation

For detailed instructions, advanced configuration, and troubleshooting, see the [Self-Hosting Guide](https://betterlytics.io/docs/installation/self-hosting).
