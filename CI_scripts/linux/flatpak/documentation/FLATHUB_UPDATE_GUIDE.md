# Flathub Update Guide for TowDow

## 📋 Overview

Once your TowDow app is published on Flathub, you'll need to follow a specific process to push updates. This guide explains how to update your application on Flathub.

## 🔄 Update Process

### **Method 1: Manual Updates (Recommended for major releases)**

#### **Step 1: Prepare Your Update**

1. **Update your application** in your main repository
2. **Create a new git tag** for the version:
   ```bash
   git tag v1.1.0
   git push origin v1.1.0
   ```

3. **Update your Flathub fork**:
   ```bash
   cd /path/to/your/flathub/fork
   git checkout main
   git pull upstream main  # Get latest Flathub changes
   ```

#### **Step 2: Update the Manifest**

1. **Navigate to your app directory**:
   ```bash
   cd apps/app.towdow.TowDow/
   ```

2. **Update the version in the manifest**:
   ```bash
   # Update the git tag in flatpak-manifest.yml
   sed -i "s/tag: v1\.0\.0/tag: v1.1.0/g" flatpak-manifest.yml
   ```

3. **Update the metainfo.xml**:
   ```bash
   # Update version in app.towdow.TowDow.metainfo.xml
   sed -i "s/<release version=\"1\.0\.0\"/<release version=\"1.1.0\"/g" app.towdow.TowDow.metainfo.xml
   
   # Add new release entry (keep old ones for history)
   sed -i "/<releases>/a\\    <release version=\"1.1.0\" date=\"$(date +%Y-%m-%d)\"/>" app.towdow.TowDow.metainfo.xml
   ```

#### **Step 3: Submit the Update**

1. **Create update branch**:
   ```bash
   git checkout -b update-to-1.1.0
   ```

2. **Commit changes**:
   ```bash
   git add .
   git commit -m "Update TowDow to version 1.1.0"
   ```

3. **Push and create PR**:
   ```bash
   git push origin update-to-1.1.0
   ```

4. **Create PR** on GitHub: https://github.com/flathub/flathub

### **Method 2: Automated Updates (Recommended for minor releases)**

#### **Setup External Data Checker (EDC)**

1. **Add EDC configuration** to your app directory:
   ```yaml
   # apps/app.towdow.TowDow/edc.yaml
   sources:
     - type: git
       url: https://gitlab.com/towdow/towdow-flutter.git
       tag: v(.*)
   ```

2. **EDC will automatically**:
   - Monitor your repository for new tags
   - Create PRs when new versions are detected
   - Update the manifest automatically

## 📝 Update Checklist

### **Before Submitting Update:**

- [ ] **New git tag created** in your repository
- [ ] **Version updated** in flatpak-manifest.yml
- [ ] **Version updated** in metainfo.xml
- [ ] **New release entry added** to metainfo.xml
- [ ] **Test build locally** (optional but recommended)
- [ ] **Changelog updated** (if applicable)

### **Files to Update:**

1. **`flatpak-manifest.yml`**:
   ```yaml
   sources:
     - type: git
       url: https://gitlab.com/towdow/towdow-flutter.git
       tag: v1.1.0  # ← Update this
   ```

2. **`app.towdow.TowDow.metainfo.xml`**:
   ```xml
   <releases>
       <release version="1.1.0" date="2024-01-15"/>  # ← Add new entry
       <release version="1.0.0" date="2024-01-01"/>  # ← Keep old entries
   </releases>
   ```

## 🚀 Quick Update Script

I'll create a script to automate the update process for you.
