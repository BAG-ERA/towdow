# Flathub Submission Guide for TowDow

## 📋 Prerequisites

Before submitting to Flathub, ensure you have:

1. **GitHub Account** (required for Flathub submission)
2. **Valid Git Tags** in your repository (e.g., `v1.0.0`)
3. **Proper App ID**: `app.towdow.TowDow` (already configured)
4. **Complete Metadata**: Desktop file, AppData, and icons (✅ done)

## 🧪 Testing Steps

### 1. Test the Manifest Locally
```bash
# Run the test script
./CI_scripts/linux/test_flathub_manifest.sh
```

### 2. Manual Testing (if needed)
```bash
# Build with the Flathub manifest
flatpak-builder \
    --repo=flathub-test-repo \
    --force-clean \
    --sandbox \
    --user \
    --install \
    --install-deps-from=flathub \
    build \
    CI_scripts/linux/flatpak/flatpak-manifest.yml

# Create bundle for testing
flatpak build-bundle flathub-test-repo towdow-test.flatpak app.towdow.TowDow

# Install and test
flatpak install --user --bundle towdow-test.flatpak
flatpak run app.towdow.TowDow
```

## 📤 Submission Process

### Step 1: Fork Flathub Repository
1. Go to https://github.com/flathub/flathub
2. Click "Fork" to create your fork
3. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/flathub.git
   cd flathub
   ```

### Step 2: Create Application Branch
```bash
# Create a new branch for your app
git checkout -b app.towdow.TowDow
```

### Step 3: Add Your Application
```bash
# Create directory for your app
mkdir -p apps/app.towdow.TowDow

# Copy your manifest
cp /path/to/towdow-flutter/CI_scripts/linux/flatpak/flatpak-manifest.yml apps/app.towdow.TowDow/

# Copy additional files if needed
cp /path/to/towdow-flutter/CI_scripts/linux/flatpak/data/* apps/app.towdow.TowDow/
```

### Step 4: Update Manifest for Flathub
The manifest needs minor adjustments for Flathub:

1. **Remove local file sources** (Flathub uses git directly)
2. **Use proper git tags** instead of commits
3. **Ensure all paths are relative to the Flathub structure**

Example Flathub manifest structure:
```yaml
app-id: app.towdow.TowDow
runtime: org.freedesktop.Platform
runtime-version: '25.08'
sdk: org.freedesktop.Sdk
sdk-extensions:
  - org.freedesktop.Sdk.Extension.llvm20

sources:
  - type: git
    url: https://gitlab.com/towdow/towdow-flutter.git
    tag: v1.0.0  # Use proper version tags
    # Include additional files as needed
```

### Step 5: Commit and Push
```bash
git add apps/app.towdow.TowDow/
git commit -m "Add TowDow task management application"
git push origin app.towdow.TowDow
```

### Step 6: Create Pull Request
1. Go to https://github.com/flathub/flathub
2. Click "New Pull Request"
3. Select your branch `app.towdow.TowDow`
4. Fill out the PR template with:
   - App description
   - License information
   - Screenshots/website links
   - Any special requirements

## 📝 Important Notes

### App ID Requirements
- ✅ Must be reverse domain notation: `app.towdow.TowDow`
- ✅ Must be unique across Flathub
- ✅ Should match your domain ownership

### License Requirements
- ✅ Your app must be open source
- ✅ License must be compatible with Flathub
- ✅ Current license: AGPL-3.0-or-later (✅ compatible)

### Metadata Requirements
- ✅ Desktop file with proper categories
- ✅ AppData file with screenshots
- ✅ Icons in multiple sizes (64x64, 128x128, 256x256)
- ✅ Proper OARS content rating

### Technical Requirements
- ✅ Must build successfully
- ✅ Must run in sandboxed environment
- ✅ Must not require additional permissions beyond declared ones
- ✅ Must follow Flathub packaging guidelines

## 🔍 Review Process

After submission:

1. **Automated Checks**: Flathub runs automated tests
2. **Manual Review**: Maintainers review your submission
3. **Feedback**: You may receive requests for changes
4. **Approval**: Once approved, your app goes live

## 📚 Resources

- [Flathub Submission Guidelines](https://docs.flathub.org/docs/for-app-authors/submission/)
- [Flatpak Manifest Reference](https://docs.flatpak.org/en/latest/manifests.html)
- [AppData Specification](https://www.freedesktop.org/software/appstream/docs/)
- [Desktop Entry Specification](https://specifications.freedesktop.org/desktop-entry-spec/)

## 🚀 Next Actions

1. **Test locally**: Run `./CI_scripts/linux/test_flathub_manifest.sh`
2. **Create proper git tags**: Ensure you have version tags like `v1.0.0`
3. **Fork Flathub**: Prepare your submission
4. **Submit PR**: Follow the submission process above

## ⚠️ Common Issues

- **App ID conflicts**: Ensure your app ID is unique
- **Missing metadata**: Verify all required files are present
- **Build failures**: Test thoroughly before submission
- **Permission issues**: Only request necessary permissions
- **Icon problems**: Ensure icons are in proper format and sizes
