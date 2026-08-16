#!/bin/bash
set -e

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

echo "Running post-migration scripts..."
node scripts/provision_roles.js
