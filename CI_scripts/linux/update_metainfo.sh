#!/bin/bash

# Script to update metainfo.xml with Git tag information for deb package
# Uses GitLab predefined CI variables for reliable data extraction

set -e  # Exit on error

# Check if required variables are set
if [ -z "$CI_COMMIT_TAG" ]; then
    echo "Error: CI_COMMIT_TAG is not set"
    exit 1
fi

if [ -z "$CI_COMMIT_TAG_MESSAGE" ]; then
    echo "Error: CI_COMMIT_TAG_MESSAGE is not set"
    exit 1
fi

if [ -z "$CI_COMMIT_TIMESTAMP" ]; then
    echo "Error: CI_COMMIT_TIMESTAMP is not set"
    exit 1
fi

echo "🔧 Updating metainfo.xml for tag: $CI_COMMIT_TAG"

# Use GitLab predefined variables
VERSION="${CI_COMMIT_TAG#v}"  # Strip leading v from tags like v1.2.3
TAG_DATE=$(echo "$CI_COMMIT_TIMESTAMP" | cut -d'T' -f1)  # Extract date from ISO timestamp
TAG_DESCRIPTION="$CI_COMMIT_TAG_MESSAGE"

echo "📦 Version: $VERSION"
echo "📅 Date: $TAG_DATE"
echo "📝 Description: $TAG_DESCRIPTION"

# Update metainfo file
METAINFO_FILE="linux/app.towdow.TowDow.metainfo.xml"
CONFIG_FILE="linux/packaging/deb/make_config.yaml"

if [ ! -f "$METAINFO_FILE" ]; then
    echo "Error: $METAINFO_FILE not found"
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: $CONFIG_FILE not found"
    exit 1
fi

echo "📝 Updating $METAINFO_FILE..."

# Update version and date - match any existing version/date pattern
sed -i "s|<release version=\"[^\"]*\" date=\"[^\"]*\">|<release version=\"$VERSION\" date=\"$TAG_DATE\">|g" "$METAINFO_FILE"

# Update description - handle multiline descriptions properly
# Escape special characters for sed
ESCAPED_DESCRIPTION=$(echo "$TAG_DESCRIPTION" | sed 's/[[\.*^$()+?{|]/\\&/g' | sed ':a;N;$!ba;s/\n/\\n/g')

# Update description - match any existing description pattern
sed -i "s|<description><p>[^<]*</p></description>|<description><p>$ESCAPED_DESCRIPTION</p></description>|g" "$METAINFO_FILE"

echo "📝 Updating $CONFIG_FILE..."

# Update version in make_config.yaml (should always exist now)
sed -i "s|^version:.*|version: \"$VERSION\"|g" "$CONFIG_FILE"

echo "✅ Updated metainfo with:"
echo "  - Version: $VERSION"
echo "  - Date: $TAG_DATE"
echo "  - Description: $TAG_DESCRIPTION"

# Show the updated release section
echo ""
echo "📋 Updated release section:"
grep -A 3 "<release" "$METAINFO_FILE" || echo "Release section not found"

echo ""
echo "📋 Updated config version:"
grep "^version:" "$CONFIG_FILE" || echo "Version line not found in config"

echo ""
echo "📋 Updated metainfo path in config:"
grep "^metainfo:" "$CONFIG_FILE" || echo "Metainfo path not found in config"

echo ""
echo "📋 Full metainfo file content (release section):"
grep -A 5 -B 1 "<release" "$METAINFO_FILE" || echo "Release section not found"

echo "✅ Metainfo update completed!"
