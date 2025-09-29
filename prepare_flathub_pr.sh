#!/bin/bash

# Quick script to prepare Flathub PR
# Usage: ./prepare_flathub_pr.sh [version]

set -euo pipefail

VERSION="${1:-1.0.0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🎯 TowDow Flathub PR Preparation"
echo "================================"
echo ""

# Check if we're in the right directory
if [[ ! -f "$SCRIPT_DIR/CI_scripts/linux/flatpak/flatpak-manifest.yml" ]]; then
    echo "❌ Error: flatpak-manifest.yml not found!"
    echo "Please run this script from the TowDow project root directory."
    exit 1
fi

# Ask for Flathub repo directory
echo "📁 Please enter the path to your Flathub repository clone:"
echo "   (Press Enter for default: /home/maxime/work/external_repos/flathub)"
read -r FLATHUB_DIR
FLATHUB_DIR="${FLATHUB_DIR:-/home/maxime/work/external_repos/flathub}"

echo ""
echo "🚀 Preparing Flathub PR for TowDow v$VERSION..."
echo "📁 Using Flathub directory: $FLATHUB_DIR"
echo ""

# Run the copy script
bash "$SCRIPT_DIR/CI_scripts/linux/flatpak/copy_file_for_PR.sh" "$FLATHUB_DIR" "$VERSION"

echo ""
echo "🎉 Flathub PR preparation complete!"
echo ""
echo "📋 Summary:"
echo "  • App ID: app.towdow.TowDow"
echo "  • Version: $VERSION"
echo "  • Files copied to: $FLATHUB_DIR/apps/app.towdow.TowDow/"
echo ""
echo "🔗 Next: Create your PR at https://github.com/flathub/flathub"
