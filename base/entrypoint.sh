#!/bin/bash
set -e

. /secrets-env.sh

# Bundled Garage replay storage; BYO-S3 (S3_ENABLED set in .env) skips it entirely
GARAGE_ENABLED=false
if [ "$SESSION_REPLAYS_ENABLED" = "true" ] && [ -z "$S3_ENABLED" ] && [ -n "$SECRET_BASE" ]; then
    GARAGE_ENABLED=true
    export GARAGE_RPC_SECRET=$(derive_hex_secret "garage-rpc" 64)
    export GARAGE_DEFAULT_ACCESS_KEY="GK$(derive_hex_secret "replay-s3-access" 24)"
    export GARAGE_DEFAULT_SECRET_KEY=$(derive_hex_secret "replay-s3-secret" 64)
    export GARAGE_DEFAULT_BUCKET="replay-storage"

    export S3_ENABLED="true"
    # The bucket name doubles as the /replay-storage nginx routing prefix
    export S3_ENDPOINT="$PUBLIC_BASE_URL"
    export S3_INTERNAL_ENDPOINT="http://127.0.0.1:3900"
    export S3_BUCKET="replay-storage"
    export S3_REGION="garage"
    export S3_ACCESS_KEY_ID="$GARAGE_DEFAULT_ACCESS_KEY"
    export S3_SECRET_ACCESS_KEY="$GARAGE_DEFAULT_SECRET_KEY"
    export S3_FORCE_PATH_STYLE="true"
    export S3_MANAGE_BUCKET_RULES="true"
fi

# Always write the file so the supervisord include glob matches; empty when Garage is off
mkdir -p /run/supervisord
if [ "$GARAGE_ENABLED" = "true" ]; then
    cat > /run/supervisord/garage.conf <<'EOF'
[program:garage]
command=/usr/local/bin/garage -c /etc/garage.toml server --single-node --default-bucket
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
autorestart=true
startsecs=5
startretries=3
priority=10
EOF
else
    : > /run/supervisord/garage.conf
fi

if [ "$HTTP_SCHEME" = "https" ] && [ -n "$SSL_DOMAIN" ]; then
    mkdir -p /var/www/certbot
    if [ ! -f "/etc/letsencrypt/live/$SSL_DOMAIN/fullchain.pem" ]; then
        echo "Obtaining SSL certificate for $SSL_DOMAIN..."
        cp /etc/nginx/templates/nginx.conf /etc/nginx/conf.d/default.conf
        nginx
        if [ -n "$SSL_EMAIL" ]; then
            CERTBOT_EMAIL_FLAG="--email $SSL_EMAIL"
        else
            CERTBOT_EMAIL_FLAG="--register-unsafely-without-email"
        fi
        if ! certbot certonly --webroot --non-interactive --agree-tos \
            $CERTBOT_EMAIL_FLAG \
            -d "$SSL_DOMAIN" \
            -w /var/www/certbot; then
            nginx -s stop
            echo "Failed to obtain certificate"
            exit 0
        fi
        nginx -s stop
    fi

    echo "Configuring nginx with SSL..."
    certbot renew
    
    export SSL_DOMAIN
    envsubst '${SSL_DOMAIN}' < /etc/nginx/templates/nginx-ssl.conf > /etc/nginx/conf.d/default.conf
else
    echo "Configuring nginx without SSL..."
    cp /etc/nginx/templates/nginx.conf /etc/nginx/conf.d/default.conf
fi

echo "Starting services..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/betterlytics.conf
