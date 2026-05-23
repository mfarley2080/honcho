#!/usr/bin/env bash
# Run as root on TrueNAS before first Portainer deploy.
# Requires build.sh to have been run first.
set -euo pipefail

BASE=/mnt/tank/docker/honcho

echo "Creating honcho data directories under ${BASE}..."
mkdir -p "${BASE}/postgres"
mkdir -p "${BASE}/redis"
mkdir -p "${BASE}/logs"

echo "Setting ownership for postgres and redis (UID/GID 999)..."
chown 999:999 "${BASE}/postgres"
chown 999:999 "${BASE}/redis"

echo "Setting ownership for logs (app user UID 100, GID 101)..."
chown 100:101 "${BASE}/logs"

echo "Done."
ls -la "${BASE}"
