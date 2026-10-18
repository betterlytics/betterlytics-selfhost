#!/bin/bash
if [ -z "$SECRET_BASE" ]; then
    echo "betterlytics: SECRET_BASE is not set. Set it in .env to 32+ random characters (openssl rand -hex 32), then run docker compose up -d --wait." >&2
    exit 1
fi
. /derive.sh

export CLICKHOUSE_PASSWORD=$(derive_secret "clickhouse-admin" 32)
export CLICKHOUSE_BACKEND_PASSWORD=$(derive_secret "clickhouse-backend" 32)
export CLICKHOUSE_DASHBOARD_PASSWORD=$(derive_secret "clickhouse-dashboard" 32)

exec /entrypoint.sh "$@"
