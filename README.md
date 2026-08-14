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
docker compose up -d
```

## Deployment Modes

### Standalone (automatic HTTPS)

`HTTP_SCHEME=https` is the default. The container will automatically provision TLS certificates via Let's Encrypt.

Ports 80 and 443 must be accessible from the internet for ACME challenges and HTTPS traffic. When using `setup.sh`, this is handled automatically, the script generates a `docker-compose.override.yml` that exposes port 443 and binds to `0.0.0.0`.

## Configuration Reference

| Variable                   | Description                                              | Default |
| -------------------------- | -------------------------------------------------------- | ------- |
| `DOMAIN`                   | Domain where your instance is accessible (no protocol)   |         |
| `ENABLE_UPTIME_MONITORING` | Enable Uptime Monitoring feature                         | `false` |
| `SESSION_REPLAYS_ENABLED`  | Enable Session Replay (see below)                        | `false` |
| `HTTP_SCHEME`              | `http` or `https`, built-in Let's Encrypt when `https`   | `https` |
| `SECRET_BASE`              | Single secret used to derive all passwords and auth keys |         |
| `ADMIN_EMAIL`              | Admin account email                                      |         |
| `ADMIN_PASSWORD`           | Admin account password                                   |         |
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
| `HTTP_PORT`                | Exposed HTTP port                                        |         |

All database passwords, `NEXTAUTH_SECRET`, and `TOTP_SECRET_ENCRYPTION_KEY` are derived automatically from `SECRET_BASE`. You only need to set one secret.

### Behind a Reverse Proxy

Set `HTTP_SCHEME=http` and bind to localhost on a non-standard port so you don't expose port 80 directly:

```
HTTP_SCHEME=http
BIND_ADDRESS=127.0.0.1
HTTP_PORT=5566
```

Then point your reverse proxy to that port. Example with **Caddy**:

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

## Session Replay

Session replay records visitor sessions and plays them back in the dashboard. Recordings are stored in S3-compatible object storage: either a bundled [Garage](https://garagehq.deuxfleurs.fr/) service that ships with this stack, or your own S3-compatible provider.

### Bundled storage (recommended)

Choose "Enabled" in the Session Replay step of `setup.sh`, or set these two lines in an existing `.env`:

```
SESSION_REPLAYS_ENABLED=true
COMPOSE_PROFILES=replay
```

Then run `docker compose up -d --wait`. This starts a Garage container plus a one-shot init container that configures CORS and storage retention. No manual bucket, credential, or CORS setup is needed: `setup.sh` generates `GARAGE_RPC_SECRET`, `REPLAY_S3_ACCESS_KEY`, and `REPLAY_S3_SECRET_KEY` in your `.env`, and the stack wires everything else together.

If your `.env` predates session replay support, add the three secrets manually:

```
GARAGE_RPC_SECRET=$(openssl rand -hex 32)
REPLAY_S3_ACCESS_KEY=GK$(openssl rand -hex 12)
REPLAY_S3_SECRET_KEY=$(openssl rand -hex 32)
```

Notes on the bundled storage:

- Segment uploads and playback go through your public domain under the `/replay-storage/` path, so no extra ports need to be exposed.
- Recordings are deleted automatically after `REPLAY_RETENTION_DAYS` (defaults to `DATA_RETENTION_DAYS`, normally 365). Set `REPLAY_RETENTION_DAYS` in `.env` before first enabling replay to change this.
- Garage does not support S3 server-side encryption. Use disk encryption on the host if you need encryption at rest.

### Bring your own S3-compatible storage

Instead of the bundled service, point the stack at any S3-compatible provider (AWS S3, Cloudflare R2, Hetzner Object Storage, ...). Set `SESSION_REPLAYS_ENABLED=true` (without `COMPOSE_PROFILES=replay`) and configure:

| Variable                 | Description                                             | Default |
| ------------------------ | ------------------------------------------------------- | ------- |
| `S3_ENABLED`             | Must be `true` to activate replay storage               | `false` |
| `S3_BUCKET`              | Bucket for replay segments                              |         |
| `S3_REGION`              | Bucket region                                           |         |
| `S3_ENDPOINT`            | Public endpoint URL (omit for AWS S3)                   |         |
| `S3_INTERNAL_ENDPOINT`   | Endpoint for server-side calls, if different from public|         |
| `S3_ACCESS_KEY_ID`       | Access key                                              |         |
| `S3_SECRET_ACCESS_KEY`   | Secret key                                              |         |
| `S3_FORCE_PATH_STYLE`    | Use path-style bucket addressing                        | `false` |
| `S3_SSE_ENABLED`         | Request SSE (AES256) on uploaded objects                | `false` |

Requirements for your bucket:

- The endpoint must be reachable from visitors' browsers (uploads) and from your browser (playback), over the same scheme as your tracked sites; an `http://` storage endpoint breaks on `https://` pages.
- A CORS rule must allow `PUT` and `GET` from your tracked sites' origins (or `*`), with all headers allowed.
- Nothing in this stack deletes objects from your bucket. Configure a lifecycle/expiration rule with your provider to bound storage growth.

### Storage growth

Each recorded session uploads compressed DOM snapshots. Expect storage usage to scale with traffic on sites that have replay enabled; the retention rule (bundled) or your provider's lifecycle rule (BYO) is what keeps it bounded.

## Requirements

- Docker and Docker Compose
- A domain name pointed to your server
- Ports 80/443 open (standalone mode) or a reverse proxy configured

## Documentation

For detailed instructions, advanced configuration, and troubleshooting, see the [Self-Hosting Guide](https://betterlytics.io/docs/installation/self-hosting).
