#!/bin/bash
set -e

if [ "$HTTP_SCHEME" = "https" ] && [ "$HTTP_PORT" != "80" ]; then
    echo "HTTP_SCHEME=https requires HTTP_PORT=80 (Let's Encrypt HTTP-01 validation) and a host mapping of port 443."
    echo "Set HTTP_PORT=80 and HTTPS_PORT=443 in .env and add the 443 mapping (setup.sh 'Standalone' writes both), or use HTTP_SCHEME=http behind your own reverse proxy."
    exit 1
fi

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
    # The dashboard refuses to boot when both status flags are on and this is empty.
    export STATUS_PAGE_ASK_SECRET=$(derive_secret "status-page-ask" 32)

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
