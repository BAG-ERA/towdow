#!/bin/bash

# Flatpak CI build script for TowDow
# Simplified version for GitLab CI integration
# Usage: build_flatpak_ci.sh <TAG> <COMMIT_ID>

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(dirname "$0")"

# Check if both TAG and COMMIT_ID arguments are provided
if [ $# -lt 2 ]; then
    echo "Error: Both TAG and COMMIT_ID arguments are required"
    echo "Usage: $0 <TAG> <COMMIT_ID>"
    exit 1
fi

TAG="$1"
COMMIT_ID="$2"

echo "update commit in app.towdow.TowDow/app.towdow.TowDow.yml"
sed -i "s/__VERSION__/${TAG}/g" "${SCRIPT_DIR}/app.towdow.TowDow/app.towdow.TowDow.yml"
sed -i "s/__COMMIT_ID__/${COMMIT_ID}/g" "${SCRIPT_DIR}/app.towdow.TowDow/app.towdow.TowDow.yml"

echo "Starting Flatpak CI build..."

# Clean up any previous builds
echo "Cleaning up previous builds..."
rm -rf repo build .flatpak-builder

# Create and initialize Flatpak repository
echo "Initializing Flatpak repository..."
mkdir -p repo
ostree init --repo=repo --mode=archive-z2

# Build the Flatpak package
echo "Building Flatpak package with TAG: ${TAG} and COMMIT_ID: ${COMMIT_ID}..."
VERSION="${TAG}" flatpak-builder \
    --repo=repo \
    --force-clean \
    --sandbox \
    --user \
    --install-deps-from=flathub \
    build \
    "${SCRIPT_DIR}/app.towdow.TowDow/app.towdow.TowDow.yml"

echo "Flatpak build completed successfully"

# Show repository references for debugging
echo "Repository references:"
ostree --repo=repo refs

echo "Flatpak CI build completed successfully!"

# Finalize repo (appstream compose + deltas)
flatpak build-update-repo --generate-static-deltas repo  || exit $?

echo "Running linter"
flatpak run --command=flatpak-builder-lint org.flatpak.Builder manifest CI_scripts/linux/flatpak/app.towdow.TowDow/app.towdow.TowDow.yml  || exit $?
# Ignore screenshot-related errors - these are expected for local builds
# Screenshots are automatically mirrored by Flathub during publishing
flatpak run --command=flatpak-builder-lint org.flatpak.Builder repo repo --exceptions appstream-screenshots-not-mirrored-in-ostree,appstream-external-screenshot-url || exit $?

echo "Linter succeeded"