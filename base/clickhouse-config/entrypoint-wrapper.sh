#!/bin/bash
if [ -n "$SECRET_BASE" ]; then
    . /derive.sh

    export CLICKHOUSE_PASSWORD=$(derive_secret "clickhouse-admin" 32)
    export CLICKHOUSE_BACKEND_PASSWORD=$(derive_secret "clickhouse-backend" 32)
    export CLICKHOUSE_DASHBOARD_PASSWORD=$(derive_secret "clickhouse-dashboard" 32)
fi

exec /entrypoint.sh "$@"
