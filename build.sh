#!/usr/bin/env bash
# Build the honcho image locally from the upstream repo.
# Run on TrueNAS before first Portainer deploy, and again when upgrading.
set -euo pipefail

TAG=v3.0.7
IMAGE=honcho
TMPDIR=$(mktemp -d)
trap "rm -rf ${TMPDIR}" EXIT

echo "Cloning plastic-labs/honcho at ${TAG}..."
git clone --depth 1 --branch "${TAG}" https://github.com/plastic-labs/honcho.git "${TMPDIR}/honcho"

echo "Building ${IMAGE}:${TAG}..."
docker build -t "${IMAGE}:${TAG}" -t "${IMAGE}:latest" "${TMPDIR}/honcho"

echo "Done."
docker images "${IMAGE}"
