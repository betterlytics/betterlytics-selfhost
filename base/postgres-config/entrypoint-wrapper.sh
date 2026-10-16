#!/bin/bash
if [ -z "$SECRET_BASE" ]; then
    echo "betterlytics: SECRET_BASE is not set. Set it in .env to 32+ random characters (openssl rand -hex 32), then run docker compose up -d --wait." >&2
    exit 1
fi
. /derive.sh
export POSTGRES_PASSWORD=$(derive_secret "postgres" 32)

exec docker-entrypoint.sh postgres
