#!/bin/bash

# Script to prepare files for Flathub PR submission
# Usage: ./copy_file_for_PR.sh --flathub-repo <path> --version <version> --commit-id <sha>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "SCRIPT_DIR: $SCRIPT_DIR"

# Initialize variables
FLATHUB_REPO_DIR=""
VERSION=""
COMMIT_SHA=""
APP_ID="app.towdow.TowDow"

# Function to show usage
show_usage() {
    echo "❌ Error: All parameters are required"
    echo "Usage: $0 --flathub-repo <path> --version <version> --commit-id <sha>"
    echo ""
    echo "Parameters:"
    echo "  --flathub-repo: Path to the Flathub repository directory"
    echo "  --version: Version number for the application"
    echo "  --commit-id: Git commit SHA for the version"
    echo ""
    echo "Example:"
    echo "  $0 --flathub-repo /home/user/flathub --version 1.0.0 --commit-id abc123def456"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --flathub-repo)
            FLATHUB_REPO_DIR="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --commit-id)
            COMMIT_SHA="$2"
            shift 2
            ;;
        *)
            echo "❌ Error: Unknown parameter '$1'"
            show_usage
            ;;
    esac
done

# Validate all required parameters are provided
if [[ -z "$FLATHUB_REPO_DIR" ]]; then
    echo "❌ Error: --flathub-repo parameter is required"
    show_usage
fi

if [[ -z "$VERSION" ]]; then
    echo "❌ Error: --version parameter is required"
    show_usage
fi

if [[ -z "$COMMIT_SHA" ]]; then
    echo "❌ Error: --commit-id parameter is required"
    show_usage
fi

# Make variables readonly
readonly FLATHUB_REPO_DIR
readonly VERSION
readonly COMMIT_SHA
readonly APP_ID

echo "🚀 Preparing Flathub PR files..."
echo "📁 Flathub repo directory: $FLATHUB_REPO_DIR"
echo "🏷️  Version: $VERSION"
echo "🔗 Commit SHA: $COMMIT_SHA"
echo "📱 App ID: $APP_ID"

# Validate flathub repo directory exists
if [[ ! -d "$FLATHUB_REPO_DIR" ]]; then
    echo "❌ Error: Flathub repository directory does not exist: $FLATHUB_REPO_DIR"
    echo "Please clone the Flathub repository first:"
    echo "  git clone https://github.com/YOUR_USERNAME/flathub.git $FLATHUB_REPO_DIR"
    exit 1
fi

# Files will be placed directly at the top level of the Flathub repo
# No app subdirectory needed per Flathub requirements
APP_DIR="$FLATHUB_REPO_DIR"
echo "📂 Files will be placed at top level of Flathub repo: $APP_DIR"

# Copy the Flathub-compliant manifest to top level
echo "📄 Copying Flathub manifest..."
cp "$SCRIPT_DIR/app.towdow.TowDow/app.towdow.TowDow.yml" "$APP_DIR/"

# Note: Desktop, metainfo, and icon files are now referenced from upstream repository
# No need to copy them locally as they will be fetched from the git source

# Function to copy Flutter files with error handling
copy_flutter_files() {
    local source_dir="$1"
    local dest_dir="$2"
    
    # Define the list of required Flutter files
    local flutter_files=(
        "flutter-sdk-3.35.3.json"
        "flutter-shared.sh.patch"
        "package_config.json"
        "pubspec-sources.json"
    )
    
    echo "📦 Copying Flutter build files..."
    
    for file in "${flutter_files[@]}"; do
        local source_file="$source_dir/$file"
        local dest_file="$dest_dir/$file"
        
        if [[ -f "$source_file" ]]; then
            echo "  ✓ Copying $file"
            cp "$source_file" "$dest_file"
        else
            echo "❌ Error: Required Flutter file not found: $file"
            echo "   Expected location: $source_file"
            echo "   Please ensure all required Flutter files are present before running this script."
            exit 1
        fi
    done
    
    echo "✅ All Flutter files copied successfully"
}

# Copy additional required files for Flutter builds
copy_flutter_files "$SCRIPT_DIR/app.towdow.TowDow" "$APP_DIR"

# Update commit sha in manifest
echo "🔢 Updating commit sha"
sed -i "s/__COMMIT_ID__/$COMMIT_SHA/g" "$APP_DIR/app.towdow.TowDow.yml"


# Create a README for the PR
echo "📝 Creating PR README..."
cat > "$APP_DIR/README.md" << EOF
# TowDow

Task management and productivity application for individuals and teams.

## App Information

- **App ID**: $APP_ID
- **Version**: $VERSION
- **Commit SHA**: $COMMIT_SHA
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
echo "📁 Files placed at top level of Flathub repo: $APP_DIR"
echo ""
echo "📋 TowDow-related files in Flathub repo root:"
ls -la "$APP_DIR" | grep -E "(app\.towdow\.TowDow\.yml|README|flutter-sdk|flutter-shared|package_config|pubspec-sources)"
echo ""
echo "🎯 Next steps:"
echo "1. cd $FLATHUB_REPO_DIR"
echo "2. git checkout -b $APP_ID"
echo "3. git add app.towdow.TowDow.yml README.md"
echo "4. git add flutter-sdk-3.35.3.json flutter-shared.sh.patch package_config.json pubspec-sources.json"
echo "5. git commit -m \"Add $APP_ID task management application\""
echo "6. git push origin $APP_ID"
echo "7. Create PR on GitHub: https://github.com/flathub/flathub"
echo ""
echo "🔍 To verify the files:"
echo "  flatpak-builder-lint $APP_DIR/app.towdow.TowDow.yml"
echo ""
echo "✨ PR preparation complete!"