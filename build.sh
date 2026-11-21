#!/usr/bin/env bash
# Build the honcho image locally from the upstream repo.
# Run on TrueNAS before first Portainer deploy, and again when upgrading.
set -euo pipefail

TAG=v3.6.2
IMAGE=honcho
TMPDIR=$(mktemp -d)
trap "rm -rf ${TMPDIR}" EXIT

echo "Cloning plastic-labs/honcho at ${TAG}..."
git clone --depth 1 --branch "${TAG}" https://github.com/plastic-labs/honcho.git "${TMPDIR}/honcho"

# CVE-2026-48710 (starlette BadHost) is fixed upstream since v3.3.0 (starlette 1.6.0),
# so no build-time patch is applied. Re-check uv.lock when bumping TAG.

echo "Building ${IMAGE}:${TAG}..."
docker build -t "${IMAGE}:${TAG}" -t "${IMAGE}:latest" "${TMPDIR}/honcho"

echo "Done."
docker images "${IMAGE}"
