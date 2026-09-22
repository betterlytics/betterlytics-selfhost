#!/bin/bash
set -e

if [ "$HTTP_SCHEME" = "https" ] && [ "$HTTP_PORT" != "80" ]; then
    echo "HTTP_SCHEME=https requires HTTP_PORT=80 (Let's Encrypt HTTP-01 validation) and a host mapping of port 443."
    echo "Set HTTP_PORT=80 and HTTPS_PORT=443 in .env and add the 443 mapping (setup.sh 'Standalone' writes both), or use HTTP_SCHEME=http behind your own reverse proxy."
    exit 1
fi

# Migrations and role provisioning run in the betterlytics-init service (init-entrypoint.sh).
. /secrets-env.sh

# Image predates Caddy: follow the upgrade guide instead of looping in supervisord.
if [ ! -x /usr/bin/caddy ]; then
    echo "This configuration requires a Betterlytics image with Caddy. Follow the upgrade guide."
    exit 1
fi

if [ "$HTTP_SCHEME" = "https" ]; then
    echo "Configuring Caddy with automatic HTTPS for $DOMAIN..."
    export CADDY_SITE="$DOMAIN"
else
    echo "Configuring Caddy without TLS..."
    export CADDY_SITE=":80"
fi
# Relative to /etc/caddy.
export CADDY_STATUS_SITE="sites/none.caddy"
if [ "$HTTP_SCHEME" = "https" ]; then
    echo "Enabling on-demand TLS for custom status page domains..."
    export CADDY_STATUS_SITE="sites/status.caddy"
fi
export CADDY_EMAIL_DIRECTIVE=""
if [ -n "$SSL_EMAIL" ]; then
    export CADDY_EMAIL_DIRECTIVE="email $SSL_EMAIL"
fi

caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

echo "Starting services..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/betterlytics.conf
