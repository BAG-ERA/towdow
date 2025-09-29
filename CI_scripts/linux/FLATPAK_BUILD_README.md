# Flatpak Build Scripts

This directory contains scripts for building TowDow as a Flatpak package using the new Flutter-based approach.

## Scripts Overview

### 1. `build_flatpak_ci.sh`
**Purpose**: Simplified script for GitLab CI integration
**Usage**: Used automatically by the CI pipeline
**Features**:
- Minimal output for CI logs
- Uses `repo/` directory for consistency with CI
- No bundle creation (handled by CI)

### 2. `build_flatpak_local.sh`
**Purpose**: Full-featured script for local development and testing
**Usage**: `./build_flatpak_local.sh [version_tag]`
**Features**:
- Creates versioned bundles
- Detailed output and instructions
- Uses `flatpak-repo/` directory to avoid conflicts
- Optional version tag (defaults to timestamp)

### 3. `build_flatpak.sh`
**Purpose**: Comprehensive script with all options
**Usage**: `./build_flatpak.sh <version_tag> [output_dir]`
**Features**:
- Configurable output directory
- Optional local installation testing
- Full error handling and validation

## Key Changes from Previous Approach

### Old Approach (AppImage-based)
- Built from existing AppImage
- Used `app.towdow.TowDow.yaml` configuration
- Required AppImage to be built first
- Limited to runtime version 48

### New Approach (Flutter-based)
- Builds Flutter app directly in Flatpak
- Uses `app.towdow.TowDow.yml` configuration
- Uses runtime version 25.08 with LLVM 20 extension
- More efficient and faster builds
- Better integration with Flutter toolchain

## Repository Structure

The scripts create a properly initialized Flatpak repository with:
```
repo/
├── config          # Repository configuration
├── objects/        # Object storage (CRITICAL - was missing before)
├── refs/           # Reference storage
├── state/          # State information
└── tmp/            # Temporary files
```

## Common Issues and Solutions

### "opendir(objects): No such file or directory"
**Cause**: Repository not properly initialized
**Solution**: Scripts now use `ostree init` to create proper structure

### Build Failures
**Common causes**:
- Missing dependencies
- Network issues during source download
- Insufficient disk space

**Debugging**:
- Check CI logs for specific error messages
- Verify all required files are present
- Ensure adequate disk space

## CI Integration

The GitLab CI configuration has been updated to:
- Remove dependency on AppImage build
- Use the new CI script
- Maintain existing artifact structure
- Keep compatibility with release process

## Local Development

For local testing:
```bash
# Build and create bundle
./build_flatpak_local.sh

# Install locally
flatpak install --user --bundle towdow.dev-*.flatpak

# Run application
flatpak run app.towdow.TowDow

# Uninstall
flatpak uninstall app.towdow.TowDow
```

## Troubleshooting

### Permission Issues
Ensure scripts are executable:
```bash
chmod +x build_flatpak*.sh
```

### Missing Dependencies
Install required Flatpak tools:
```bash
# Ubuntu/Debian
sudo apt install flatpak flatpak-builder

# Fedora
sudo dnf install flatpak flatpak-builder
```

### Repository Issues
If repository becomes corrupted:
```bash
rm -rf repo flatpak-repo
# Scripts will recreate with proper structure
```
