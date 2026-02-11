#!/bin/bash
set -e

# Derive ClickHouse passwords from SECRET_BASE (matches selfhost entrypoint derivation)
if [ -n "$SECRET_BASE" ]; then
    derive_secret() {
        _result="" _i=0
        while [ ${#_result} -lt "$2" ]; do
            _chunk=$(printf '%s:%d' "$1" "$_i" | openssl dgst -sha256 -hmac "$SECRET_BASE" -binary | openssl base64 -A | tr '+/' '-_' | tr -d '=')
            _result="${_result}${_chunk}" _i=$((_i + 1))
        done
        printf '%s' "$_result" | head -c "$2"
    }

    export CLICKHOUSE_BACKEND_PASSWORD=$(derive_secret "clickhouse-backend" 32)
    export CLICKHOUSE_DASHBOARD_PASSWORD=$(derive_secret "clickhouse-dashboard" 32)
    export CLICKHOUSE_ADMIN_PASSWORD=$(derive_secret "clickhouse-admin" 32)
fi

# Create a user for backend ingress
clickhouse-client --query="CREATE USER IF NOT EXISTS ${CLICKHOUSE_BACKEND_USER} IDENTIFIED BY '${CLICKHOUSE_BACKEND_PASSWORD}';"

# Create a user for dashboard egress
clickhouse-client --query="CREATE USER IF NOT EXISTS ${CLICKHOUSE_DASHBOARD_USER} IDENTIFIED BY '${CLICKHOUSE_DASHBOARD_PASSWORD}';"

# Create roles
clickhouse-client --query="CREATE ROLE dashboard_role;"
clickhouse-client --query="CREATE ROLE backend_role;"

# Grant privileges to roles
clickhouse-client --query="GRANT SELECT ON analytics.*, INSERT ON analytics.*, ALTER ON analytics.*, CREATE VIEW ON analytics.*, SELECT ON system.databases, SELECT ON system.tables TO backend_role;"
clickhouse-client --query="GRANT SELECT ON analytics.* TO dashboard_role;"

# Assign roles to users
clickhouse-client --query="GRANT backend_role TO ${CLICKHOUSE_BACKEND_USER};"
clickhouse-client --query="GRANT dashboard_role TO ${CLICKHOUSE_DASHBOARD_USER};"

# Set admin password
clickhouse-client --query="ALTER USER ${CLICKHOUSE_USER:-admin} IDENTIFIED BY '${CLICKHOUSE_ADMIN_PASSWORD}';"
