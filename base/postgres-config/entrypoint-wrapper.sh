#!/bin/bash
if [ -n "$SECRET_BASE" ]; then
    . /derive.sh
    export POSTGRES_PASSWORD=$(derive_secret "postgres" 32)
fi

exec docker-entrypoint.sh postgres
