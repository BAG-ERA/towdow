#!/bin/bash

# Flatpak local build script for TowDow
# This script builds a Flatpak package for local testing and development
# Usage: build_flatpak_local.sh [version_tag]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERSION_TAG="${1:-dev-$(date +%Y%m%d-%H%M%S)}"

echo "Building Flatpak for TowDow version: $VERSION_TAG"
echo "Project root: $PROJECT_ROOT"

# Change to project root
cd "$PROJECT_ROOT"

# Clean up any previous builds
echo "Cleaning up previous builds..."
rm -rf flatpak-repo build .flatpak-builder

# Create and initialize Flatpak repository
echo "Initializing Flatpak repository..."
mkdir -p flatpak-repo
ostree init --repo=flatpak-repo --mode=archive-z2

# Build the Flatpak package
echo "Building Flatpak package..."
flatpak-builder \
    --repo=flatpak-repo \
    --force-clean \
    --sandbox \
    --user \
    --install \
    --install-deps-from=flathub \
    build \
    app.towdow.TowDow.yml

# Create bundle from repository
echo "Creating Flatpak bundle..."
FLATPAK_BUNDLE="towdow.$VERSION_TAG.flatpak"

flatpak build-bundle \
    flatpak-repo \
    "$FLATPAK_BUNDLE" \
    app.towdow.TowDow \
    stable

# Verify bundle creation
if [[ ! -f "$FLATPAK_BUNDLE" ]]; then
    echo "Error: Failed to create Flatpak bundle"
    exit 1
fi

echo "Flatpak bundle created: $FLATPAK_BUNDLE"

# Display bundle information
echo "Bundle information:"
ls -lh "$FLATPAK_BUNDLE"

# Show repository references
echo "Repository references:"
ostree --repo=flatpak-repo refs

echo ""
echo "🎉 Flatpak build completed successfully!"
echo "📦 Bundle: $FLATPAK_BUNDLE"
echo "📁 Repository: flatpak-repo/"
echo ""
echo "To install the bundle locally:"
echo "  flatpak install --user --bundle $FLATPAK_BUNDLE"
echo ""
echo "To run the application:"
echo "  flatpak run app.towdow.TowDow"
echo ""
echo "To uninstall:"
echo "  flatpak uninstall app.towdow.TowDow"
