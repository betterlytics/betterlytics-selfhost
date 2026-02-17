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

## Requirements

- Docker and Docker Compose
- A domain name pointed to your server
- Ports 80/443 open (standalone mode) or a reverse proxy configured

## Documentation

For detailed instructions, advanced configuration, and troubleshooting, see the [Self-Hosting Guide](https://betterlytics.io/docs/installation/self-hosting).
