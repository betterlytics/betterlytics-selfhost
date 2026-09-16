#!/bin/bash
set -e

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
export CADDY_EMAIL_DIRECTIVE=""
if [ -n "$SSL_EMAIL" ]; then
    export CADDY_EMAIL_DIRECTIVE="email $SSL_EMAIL"
fi

caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

echo "Starting services..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/betterlytics.conf
