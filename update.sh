#!/bin/sh
set -e

# -----------------------------------------------
# Betterlytics Self-Hosted Updater
# -----------------------------------------------
# Updates this repository (configuration + pinned image version)
# and applies the update. For major upgrades, read the "Upgrading"
# section of the README first (backups, disk space).

# The braces force the shell to read the entire script before executing
# anything, so 'git pull' replacing this file mid-run is safe.
{
    echo "Updating betterlytics-selfhost repository..."
    git pull --ff-only

    echo "Pulling images..."
    docker compose pull

    echo "Applying update..."
    docker compose up -d --wait

    echo ""
    echo "Update complete."
    exit 0
}
