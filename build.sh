#!/usr/bin/env bash
# Build the honcho image locally from the upstream repo.
# Run on TrueNAS before first Portainer deploy, and again when upgrading.
set -euo pipefail

TAG=v3.2.0
IMAGE=honcho
TMPDIR=$(mktemp -d)
trap "rm -rf ${TMPDIR}" EXIT

echo "Cloning plastic-labs/honcho at ${TAG}..."
git clone --depth 1 --branch "${TAG}" https://github.com/plastic-labs/honcho.git "${TMPDIR}/honcho"

# CVE-2026-48710: BadHost host-header auth bypass — fixed in starlette >=1.0.1.
# Check whether the cloned tag already includes the fix; patch only if needed.
_STARLETTE_VER=$(grep -A1 '^name = "starlette"' "${TMPDIR}/honcho/uv.lock" | grep 'version' | sed 's/.*version = "\(.*\)"/\1/')
_REQUIRED="1.0.1"
if printf '%s\n%s\n' "${_REQUIRED}" "${_STARLETTE_VER}" | sort -V -C 2>/dev/null; then
    echo "NOTE: ${TAG} ships starlette ${_STARLETTE_VER} (>= ${_REQUIRED}) — CVE-2026-48710 patch no longer needed."
    echo "      Remove the CVE-2026-48710 patch block from build.sh and its row from the README security table."
else
    echo "Patching starlette ${_STARLETTE_VER} -> >=${_REQUIRED} (CVE-2026-48710)..."
    docker run --rm \
        -v "${TMPDIR}/honcho:/app" \
        -w /app \
        python:3.13-slim-bookworm \
        bash -c "pip install --quiet uv && uv lock --upgrade-package starlette"
    _STARLETTE_VER=$(grep -A1 '^name = "starlette"' "${TMPDIR}/honcho/uv.lock" | grep 'version' | sed 's/.*version = "\(.*\)"/\1/')
    if ! printf '%s\n%s\n' "${_REQUIRED}" "${_STARLETTE_VER}" | sort -V -C 2>/dev/null; then
        echo "ERROR: failed to upgrade starlette to >=${_REQUIRED} (got ${_STARLETTE_VER})." >&2
        exit 1
    fi
fi

echo "Building ${IMAGE}:${TAG}..."
docker build -t "${IMAGE}:${TAG}" -t "${IMAGE}:latest" "${TMPDIR}/honcho"

echo "Done."
docker images "${IMAGE}"
