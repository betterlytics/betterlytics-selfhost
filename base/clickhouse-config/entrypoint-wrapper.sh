#!/bin/bash
# Derive the admin password from SECRET_BASE before the ClickHouse entrypoint runs.
# The entrypoint uses CLICKHOUSE_PASSWORD to set the admin user's password in XML config.
if [ -n "$SECRET_BASE" ]; then
    derive_secret() {
        _result="" _i=0
        while [ ${#_result} -lt "$2" ]; do
            _chunk=$(printf '%s:%d' "$1" "$_i" | openssl dgst -sha256 -hmac "$SECRET_BASE" -binary | openssl base64 -A | tr '+/' '-_' | tr -d '=')
            _result="${_result}${_chunk}" _i=$((_i + 1))
        done
        printf '%s' "$_result" | head -c "$2"
    }

    export CLICKHOUSE_PASSWORD=$(derive_secret "clickhouse-admin" 32)
fi

exec /entrypoint.sh "$@"
