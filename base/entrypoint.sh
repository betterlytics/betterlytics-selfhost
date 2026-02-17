#!/bin/bash
set -e

export PATH="/app/initializer/node_modules/.bin:$PATH"

if [ -n "$SECRET_BASE" ]; then
    . /derive.sh

    export CLICKHOUSE_PASSWORD=$(derive_secret "clickhouse-admin" 32)
    export CLICKHOUSE_BACKEND_PASSWORD=$(derive_secret "clickhouse-backend" 32)
    export CLICKHOUSE_DASHBOARD_PASSWORD=$(derive_secret "clickhouse-dashboard" 32)
    export POSTGRES_PASSWORD=$(derive_secret "postgres" 32)
    export POSTGRES_SITECONFIG_RO_PASSWORD=$(derive_secret "postgres-siteconfig-ro" 32)
    export NEXTAUTH_SECRET=$(derive_secret "nextauth" 64)
    export TOTP_SECRET_ENCRYPTION_KEY=$(derive_secret "totp-encryption" 32)

    export POSTGRES_URL="postgresql://user:${POSTGRES_PASSWORD}@postgres:5432/dashboard?schema=public"
    export SITE_CONFIG_DATABASE_URL="postgresql://siteconfig_ro:${POSTGRES_SITECONFIG_RO_PASSWORD}@postgres:5432/dashboard"
fi

echo "Running ClickHouse migrations..."
cd /app/initializer
NODE_ENV=production node scripts/run-migration.js

echo "Running PostgreSQL migrations..."
prisma migrate deploy --schema /app/initializer/prisma/schema.prisma

echo "Running post-migration scripts..."
node scripts/post_migrate_siteconfig_ro.js
node scripts/post_migrate_monitoring_ro.js

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
