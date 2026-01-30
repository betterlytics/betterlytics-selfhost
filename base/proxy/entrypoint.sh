#!/bin/sh
if [ "$ENABLE_HTTPS" = "true" ]; then
    cp /etc/caddy/Caddyfile.https /etc/caddy/Caddyfile
else
    cp /etc/caddy/Caddyfile.http /etc/caddy/Caddyfile
fi
exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
