#!/bin/bash

# Flatpak CI build script for TowDow
# Simplified version for GitLab CI integration
# Usage: build_flatpak_ci.sh <COMMIT_ID>

set -euo pipefail

# Check if COMMIT_ID argument is provided
if [ $# -eq 0 ]; then
    echo "Error: COMMIT_ID argument is required"
    echo "Usage: $0 <COMMIT_ID>"
    exit 1
fi

COMMIT_ID="$1"

echo "update commit in app.towdow.TowDow/app.towdow.TowDow.yml"
sed -i "s/__COMMIT_ID__/${COMMIT_ID}/g" app.towdow.TowDow/app.towdow.TowDow.yml

echo "Starting Flatpak CI build..."

# Clean up any previous builds
echo "Cleaning up previous builds..."
rm -rf repo build .flatpak-builder

# Create and initialize Flatpak repository
echo "Initializing Flatpak repository..."
mkdir -p repo
ostree init --repo=repo --mode=archive-z2

# Build the Flatpak package
echo "Building Flatpak package..."
flatpak-builder \
    --repo=repo \
    --force-clean \
    --sandbox \
    --user \
    --install \
    --install-deps-from=flathub \
    build \
    app.towdow.TowDow.yml

echo "Flatpak build completed successfully"

# Show repository references for debugging
echo "Repository references:"
ostree --repo=repo refs

echo "Flatpak CI build completed successfully!"
