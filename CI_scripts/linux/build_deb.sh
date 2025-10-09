#!/bin/bash

# Build script for creating .deb package with TowDow
# This script ensures all code generation steps run before fastforge builds
# uses https://fastforge.dev/makers/deb

set -e  # Exit on error

echo "🔧 Running pre-build steps..."

# be sure to be at the root of the project
cd "$(dirname "$0")/../../"
echo "building in directory $(pwd)"

# Run required pre-build commands
echo "📦 Running flutter pub get..."
flutter pub get

echo "🏗️  Running build_runner..."
dart run build_runner build --delete-conflicting-outputs

echo "🌐 Generating localizations..."
flutter gen-l10n

echo "✅ Pre-build steps completed!"
echo ""
echo "🚀 Starting fastforge packaging..."

# Clean any previous deb build artifacts to ensure fresh build
echo "🧹 Cleaning previous deb build artifacts..."
rm -rf dist/ || true

# Run fastforge to build the .deb package
# Use --skip-clean to preserve generated files from build_runner, but clean deb artifacts
fastforge package --platform linux --targets deb --skip-clean

echo "📋 Verifying package version..."
if [ -n "$CI_COMMIT_TAG" ]; then
    EXPECTED_VERSION="${CI_COMMIT_TAG#v}"
    echo "Expected version: $EXPECTED_VERSION"
    
    # Check if the built package exists and show its version
    DEB_FILE=$(find dist -name "*.deb" | head -1)
    if [ -n "$DEB_FILE" ]; then
        echo "Built package: $DEB_FILE"
        dpkg-deb --field "$DEB_FILE" Version || echo "Could not extract version from package"
    else
        echo "No .deb file found in dist/"
    fi
fi

echo "✅ Build complete!"
