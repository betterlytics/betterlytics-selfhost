#!/bin/bash
# One-shot migration + provisioning run by the betterlytics-init service.
# The app container starts only after this exits 0.
set -e

# APP_VERSION is baked into images built from a release tag; older images lack it.
if [ -z "$APP_VERSION" ]; then
    if [ ! -x /usr/bin/caddy ]; then
        echo "This configuration requires a Betterlytics image with Caddy. Follow the upgrade guide."
        exit 1
    fi
elif [ "$APP_VERSION" != "dev" ] && [ "$SKIP_VERSION_CHECK" != "true" ] && [ "$APP_VERSION" != "$BETTERLYTICS_VERSION" ]; then
    echo "Configuration/image version mismatch."
    echo "  betterlytics-selfhost repo: $BETTERLYTICS_VERSION"
    echo "  image:                      $APP_VERSION"
    if [ "$(printf '%s\n%s\n' "$BETTERLYTICS_VERSION" "$APP_VERSION" | sort -V | head -n1)" = "$BETTERLYTICS_VERSION" ]; then
        echo "The repo is older: run \`git pull\` in betterlytics-selfhost, then \`docker compose up -d --wait\`."
    else
        echo "The image is older: check docker-compose.override.yml for an image override, or run \`docker compose pull\`."
    fi
    exit 1
fi

export PATH="/app/initializer/node_modules/.bin:$PATH"
. /secrets-env.sh

cd /app/initializer

echo "Running ClickHouse migrations..."
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

echo "Migrations complete."
