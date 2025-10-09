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

if [ ! -f "$METAINFO_FILE" ]; then
    echo "Error: $METAINFO_FILE not found"
    exit 1
fi

echo "📝 Updating $METAINFO_FILE..."

# Update version and date
sed -i "s|<release version=\"0\.0\.0\" date=\"2025-08-19\">|<release version=\"$VERSION\" date=\"$TAG_DATE\">|g" "$METAINFO_FILE"

# Update description - handle multiline descriptions properly
# Escape special characters for sed
ESCAPED_DESCRIPTION=$(echo "$TAG_DESCRIPTION" | sed 's/[[\.*^$()+?{|]/\\&/g' | sed ':a;N;$!ba;s/\n/\\n/g')

sed -i "s|<description><p>__release_note__</p></description>|<description><p>$ESCAPED_DESCRIPTION</p></description>|g" "$METAINFO_FILE"

echo "✅ Updated metainfo with:"
echo "  - Version: $VERSION"
echo "  - Date: $TAG_DATE"
echo "  - Description: $TAG_DESCRIPTION"

# Show the updated release section
echo ""
echo "📋 Updated release section:"
grep -A 3 "<release" "$METAINFO_FILE" || echo "Release section not found"

echo "✅ Metainfo update completed!"
