#!/bin/bash
# Derive the admin password from SECRET_BASE before the ClickHouse entrypoint runs.
# The entrypoint uses CLICKHOUSE_PASSWORD to set the admin user's password in XML config.
if [ -n "$SECRET_BASE" ]; then
    . /derive.sh

    export CLICKHOUSE_PASSWORD=$(derive_secret "clickhouse-admin" 32)
    export CLICKHOUSE_BACKEND_PASSWORD=$(derive_secret "clickhouse-backend" 32)
    export CLICKHOUSE_DASHBOARD_PASSWORD=$(derive_secret "clickhouse-dashboard" 32)
fi

exec /entrypoint.sh "$@"
