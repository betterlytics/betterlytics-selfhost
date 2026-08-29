#!/bin/sh
. /derive.sh

if [ -n "$SECRET_BASE" ]; then
    export CLICKHOUSE_PASSWORD=$(derive_secret "clickhouse-admin" 32)
    export CLICKHOUSE_BACKEND_PASSWORD=$(derive_secret "clickhouse-backend" 32)
    export CLICKHOUSE_DASHBOARD_PASSWORD=$(derive_secret "clickhouse-dashboard" 32)
    export WORKER_CLICKHOUSE_WRITE_PASSWORD=$(derive_secret "clickhouse-worker" 32)
    export POSTGRES_PASSWORD=$(derive_secret "postgres" 32)
    export POSTGRES_SITECONFIG_RO_PASSWORD=$(derive_secret "postgres-siteconfig-ro" 32)
    export POSTGRES_MONITORING_RO_PASSWORD=$(derive_secret "postgres-monitoring-ro" 32)
    export POSTGRES_SALTS_RW_PASSWORD=$(derive_secret "postgres-salts-rw" 32)
    export AUTH_SECRET=$(derive_secret "nextauth" 64)
    export TOTP_SECRET_ENCRYPTION_KEY=$(derive_secret "totp-encryption" 32)
    export INTEGRATION_ENCRYPTION_KEY=$(derive_secret "integration-encryption" 32)

    export POSTGRES_URL="postgresql://user:${POSTGRES_PASSWORD}@postgres:5432/dashboard?schema=public"
    export SITE_CONFIG_DATABASE_URL="postgresql://siteconfig_ro:${POSTGRES_SITECONFIG_RO_PASSWORD}@postgres:5432/dashboard"
    export MONITORING_DATABASE_URL="postgresql://monitoring_ro:${POSTGRES_MONITORING_RO_PASSWORD}@postgres:5432/dashboard"
    export SALTS_DATABASE_URL="postgresql://salts_rw:${POSTGRES_SALTS_RW_PASSWORD}@postgres:5432/dashboard"
fi
