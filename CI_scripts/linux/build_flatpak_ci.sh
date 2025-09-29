#!/bin/bash

# Flatpak CI build script for TowDow
# Simplified version for GitLab CI integration
# Usage: build_flatpak_ci.sh

set -euo pipefail

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
