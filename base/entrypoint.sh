#!/bin/bash
set -e

export PATH="/app/initializer/node_modules/.bin:$PATH"

if [ -n "$SECRET_BASE" ]; then
    . /derive.sh

    export CLICKHOUSE_PASSWORD=$(derive_secret "clickhouse-admin" 32)
    export CLICKHOUSE_BACKEND_PASSWORD=$(derive_secret "clickhouse-backend" 32)
    export CLICKHOUSE_DASHBOARD_PASSWORD=$(derive_secret "clickhouse-dashboard" 32)
    export WORKER_CLICKHOUSE_WRITE_PASSWORD=$(derive_secret "clickhouse-worker" 32)
    export POSTGRES_PASSWORD=$(derive_secret "postgres" 32)
    export POSTGRES_SITECONFIG_RO_PASSWORD=$(derive_secret "postgres-siteconfig-ro" 32)
    export POSTGRES_MONITORING_RO_PASSWORD=$(derive_secret "postgres-monitoring-ro" 32)
    export POSTGRES_SALTS_RW_PASSWORD=$(derive_secret "postgres-salts-rw" 32)
    export POSTGRES_JOBQUEUE_RW_PASSWORD=$(derive_secret "postgres-jobqueue-rw" 32)
    export AUTH_SECRET=$(derive_secret "auth" 64)
    export INTEGRATION_ENCRYPTION_KEY=$(derive_secret "integration-encryption" 32)

    export POSTGRES_URL="postgresql://user:${POSTGRES_PASSWORD}@postgres:5432/dashboard?schema=public"
    export SITE_CONFIG_DATABASE_URL="postgresql://siteconfig_ro:${POSTGRES_SITECONFIG_RO_PASSWORD}@postgres:5432/dashboard"
    export MONITORING_DATABASE_URL="postgresql://monitoring_ro:${POSTGRES_MONITORING_RO_PASSWORD}@postgres:5432/dashboard"
    export SALTS_DATABASE_URL="postgresql://salts_rw:${POSTGRES_SALTS_RW_PASSWORD}@postgres:5432/dashboard"
    export JOB_QUEUE_DATABASE_URL="postgresql://jobqueue_rw:${POSTGRES_JOBQUEUE_RW_PASSWORD}@postgres:5432/dashboard"
fi

echo "Running ClickHouse migrations..."
cd /app/initializer
NODE_ENV=production node scripts/run-migration.js

if [ -f scripts/post_migrate_clickhouse.js ]; then
    echo "Running ClickHouse post-migration grants..."
    node scripts/post_migrate_clickhouse.js
fi

echo "Running PostgreSQL migrations..."
prisma migrate deploy --schema /app/initializer/prisma/schema.prisma

echo "Running pg-boss migrations..."
node scripts/migrate_pgboss.js

echo "Running post-migration scripts..."
node scripts/provision_roles.js

# A checkout on an image without Caddy: fail readable instead of a supervisord restart loop.
if [ ! -x /usr/bin/caddy ]; then
    echo "This configuration requires a Betterlytics image with Caddy. Run: docker compose pull"
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
