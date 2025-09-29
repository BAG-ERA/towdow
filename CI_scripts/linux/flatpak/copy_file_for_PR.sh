#!/bin/bash

# Script to prepare files for Flathub PR submission
# Usage: ./copy_file_for_PR.sh [flathub_repo_dir] [version]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Default values
FLATHUB_REPO_DIR="${1:-/home/maxime/work/external_repos/flathub}"
VERSION="${2:-1.0.0}"
APP_ID="app.towdow.TowDow"

echo "🚀 Preparing Flathub PR files..."
echo "📁 Flathub repo directory: $FLATHUB_REPO_DIR"
echo "🏷️  Version: $VERSION"
echo "📱 App ID: $APP_ID"

# Validate flathub repo directory exists
if [[ ! -d "$FLATHUB_REPO_DIR" ]]; then
    echo "❌ Error: Flathub repository directory does not exist: $FLATHUB_REPO_DIR"
    echo "Please clone the Flathub repository first:"
    echo "  git clone https://github.com/YOUR_USERNAME/flathub.git $FLATHUB_REPO_DIR"
    exit 1
fi

# Create app directory in Flathub repo
APP_DIR="$FLATHUB_REPO_DIR/apps/$APP_ID"
echo "📂 Creating app directory: $APP_DIR"
mkdir -p "$APP_DIR"

# Copy the Flathub-compliant manifest
echo "📄 Copying Flathub manifest..."
cp "$SCRIPT_DIR/flatpak-manifest.yml" "$APP_DIR/"

# Copy metadata files
echo "📋 Copying metadata files..."
cp "$SCRIPT_DIR/data/app.towdow.TowDow.desktop" "$APP_DIR/"
cp "$SCRIPT_DIR/data/app.towdow.TowDow.metainfo.xml" "$APP_DIR/"

# Copy icons
echo "🎨 Copying icons..."
mkdir -p "$APP_DIR/icons"
cp -r "$SCRIPT_DIR/data/icons/"* "$APP_DIR/icons/"

# Copy additional required files for Flutter builds
echo "📦 Copying Flutter build files..."
if [[ -f "$PROJECT_ROOT/pubspec-sources.json" ]]; then
    cp "$PROJECT_ROOT/pubspec-sources.json" "$APP_DIR/"
else
    echo "⚠️  Warning: pubspec-sources.json not found. You may need to generate it."
fi

if [[ -f "$PROJECT_ROOT/flutter-sdk-3.35.3.json" ]]; then
    cp "$PROJECT_ROOT/flutter-sdk-3.35.3.json" "$APP_DIR/"
else
    echo "⚠️  Warning: flutter-sdk-3.35.3.json not found. You may need to generate it."
fi

# Update version numbers in files
echo "🔢 Updating version numbers..."
sed -i "s/0\.0\.0/$VERSION/g" "$APP_DIR/app.towdow.TowDow.metainfo.xml"
sed -i "s/v1\.0\.0/v$VERSION/g" "$APP_DIR/flatpak-manifest.yml"

# Create a README for the PR
echo "📝 Creating PR README..."
cat > "$APP_DIR/README.md" << EOF
# TowDow

Task management and productivity application for individuals and teams.

## App Information

- **App ID**: $APP_ID
- **Version**: $VERSION
- **License**: AGPL-3.0-or-later
- **Homepage**: https://towdow.app
- **Repository**: https://gitlab.com/towdow/towdow-flutter

## Features

- Task creation and management
- Project organization
- Calendar integration
- Team collaboration
- Cross-platform synchronization

## Screenshots

- Main interface: https://towdow.gitlab.io/screenshots/screenshot_tasks_demo1.png
- Team collaboration: https://towdow.gitlab.io/screenshots/screenshot_attendees.png

## Build Requirements

This application is built using Flutter and requires:
- Flutter SDK 3.35.3
- LLVM 20 extension
- Freedesktop Platform 25.08

## Testing

The application has been tested locally and builds successfully with the provided manifest.
EOF

# Show what was copied
echo ""
echo "✅ Files copied successfully!"
echo "📁 App directory: $APP_DIR"
echo ""
echo "📋 Files in app directory:"
ls -la "$APP_DIR"
echo ""
echo "🎯 Next steps:"
echo "1. cd $FLATHUB_REPO_DIR"
echo "2. git checkout -b $APP_ID"
echo "3. git add apps/$APP_ID/"
echo "4. git commit -m \"Add $APP_ID task management application\""
echo "5. git push origin $APP_ID"
echo "6. Create PR on GitHub: https://github.com/flathub/flathub"
echo ""
echo "🔍 To verify the files:"
echo "  flatpak-builder-lint $APP_DIR/flatpak-manifest.yml"
echo ""
echo "✨ PR preparation complete!"