#!/usr/bin/env bash
# Run as root on TrueNAS after the first GitHub Actions build completes.
set -euo pipefail

BASE=/mnt/tank/docker/honcho
IMAGE=ghcr.io/mfarley2080/honcho:latest

echo "Creating honcho data directories under ${BASE}..."
mkdir -p "${BASE}/postgres"
mkdir -p "${BASE}/redis"
mkdir -p "${BASE}/logs"

echo "Setting ownership for postgres and redis (UID/GID 999)..."
chown 999:999 "${BASE}/postgres"
chown 999:999 "${BASE}/redis"

echo "Pulling honcho image to confirm app user UID..."
if docker pull "${IMAGE}" > /dev/null 2>&1; then
    APP_UID=$(docker run --rm "${IMAGE}" id -u app 2>/dev/null || echo "")
    APP_GID=$(docker run --rm "${IMAGE}" id -g app 2>/dev/null || echo "")
    if [[ -n "${APP_UID}" && -n "${APP_GID}" ]]; then
        echo "app user confirmed: UID=${APP_UID} GID=${APP_GID}"
        chown "${APP_UID}:${APP_GID}" "${BASE}/logs"
    else
        echo "Could not read app user from image — falling back to expected 100:101"
        chown 100:101 "${BASE}/logs"
    fi
else
    echo "Could not pull image (not yet built?) — falling back to expected 100:101"
    echo "Re-run this script after the first GitHub Actions build completes."
    chown 100:101 "${BASE}/logs"
fi

echo "Done."
ls -la "${BASE}"
