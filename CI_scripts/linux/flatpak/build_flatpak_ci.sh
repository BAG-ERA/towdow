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
# Save the current directory and get absolute path to project root
PROJECT_ROOT="$(pwd)"
# Change to the manifest directory to ensure proper relative path resolution
cd "${SCRIPT_DIR}/app.towdow.TowDow"
# Note: --sandbox is removed for CI/Docker environments where namespace creation may be restricted
VERSION="${TAG}" flatpak-builder \
    --repo="${PROJECT_ROOT}/repo" \
    --force-clean \
    --disable-rofiles-fuse \
    --install-deps-from=flathub \
    "${PROJECT_ROOT}/build" \
    app.towdow.TowDow.yml
# Return to the original directory
cd "${PROJECT_ROOT}"

echo "Flatpak build completed successfully"

# Show repository references for debugging
echo "Repository references:"
ostree --repo=repo refs

echo "Flatpak CI build completed successfully!"

# Finalize repo (appstream compose + deltas)
flatpak build-update-repo --generate-static-deltas repo  || exit $?

# TODO: make the linter work in CI
echo "!!!! Flatpak linter disabled (not woring in CI) !!!!"

#echo "installing linter"
#flatpak install flathub org.flatpak.Builder -y
#
#echo "Running linter"
#flatpak run --command=flatpak-builder-lint org.flatpak.Builder manifest "${SCRIPT_DIR}/app.towdow.TowDow/app.towdow.TowDow.yml"  || exit $?
#
## Run repo linter and check for errors other than screenshot-related ones
## Screenshots are automatically mirrored by Flathub during publishing, so these errors are expected locally
#LINT_OUTPUT=$(flatpak run --command=flatpak-builder-lint org.flatpak.Builder repo repo 2>&1)
#LINT_EXIT_CODE=$?
#
#if [ $LINT_EXIT_CODE -ne 0 ]; then
#    echo "$LINT_OUTPUT"
#    echo "Info: Ignoring screenshot-related errors (expected for local builds)"
#fi
#
#echo "Linter succeeded"