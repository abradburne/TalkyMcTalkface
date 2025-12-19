# TalkyMcTalkface Distribution Guide

This document covers the complete process for building, signing, notarizing, and distributing TalkyMcTalkface as a macOS application.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Apple Developer Setup](#apple-developer-setup)
4. [Build Process](#build-process)
5. [Code Signing](#code-signing)
6. [Notarization](#notarization)
7. [DMG Creation](#dmg-creation)
8. [Troubleshooting](#troubleshooting)

## Prerequisites

### Development Environment

- **macOS 14+** (Sonoma or later)
- **Xcode 15+** with Command Line Tools
- **Python 3.11+** with virtual environment
- **PyInstaller** for Python bundling

### Python Dependencies

```bash
# Activate virtual environment
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt
pip install pyinstaller
```

### Verify Installation

```bash
# Check Xcode
xcode-select -p
xcodebuild -version

# Check Python
python3 --version

# Check code signing tools
codesign --help
xcrun notarytool --version
```

## Quick Start

For a complete build with all steps:

```bash
# Full build (Python + Swift + Sign + DMG)
./scripts/build_distribution.sh

# Build without notarization (no Apple credentials needed)
./scripts/build_distribution.sh --skip-notarize

# Build only (no signing or DMG)
./scripts/build_distribution.sh --skip-sign --skip-dmg
```

Output:
- App bundle: `build/Release/TalkyMcTalkface.app`
- DMG installer: `dist/TalkyMcTalkface.dmg`

## Apple Developer Setup

### Required Certificates

To distribute outside the App Store, you need:

1. **Developer ID Application** certificate - for signing the app
2. **Developer ID Installer** certificate - for signing the DMG (optional but recommended)

### Creating Certificates

1. Go to [developer.apple.com/account](https://developer.apple.com/account)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Click **+** to create a new certificate
4. Select **Developer ID Application**
5. Follow the CSR (Certificate Signing Request) process:
   - Open Keychain Access
   - Certificate Assistant > Request a Certificate from a Certificate Authority
   - Save to disk
   - Upload to Apple
6. Download and double-click to install

### Verify Certificates

```bash
# List available signing identities
security find-identity -v -p codesigning

# You should see something like:
# "Developer ID Application: Your Name (TEAMID)"
```

### Notarization Credentials

For notarization, create an app-specific password:

1. Go to [appleid.apple.com](https://appleid.apple.com)
2. Sign in and go to **App-Specific Passwords**
3. Generate a new password for "TalkyMcTalkface Notarization"

Store credentials in keychain (recommended):

```bash
xcrun notarytool store-credentials TalkyMcTalkface-notarize \
  --apple-id your@email.com \
  --team-id YOURTEAMID \
  --password xxxx-xxxx-xxxx-xxxx
```

Or use environment variables:

```bash
export APPLE_ID="your@email.com"
export APPLE_TEAM_ID="YOURTEAMID"
export APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"
```

## Build Process

### Step 1: Build Python Backend

The Python backend is bundled using PyInstaller:

```bash
./scripts/build_python_backend.sh
```

This creates `dist/TalkyMcTalkface/` containing:
- `TalkyMcTalkface` - Main executable
- `prompts/` - Voice prompt files
- `app/` - Application templates and static files
- Various Python libraries and dependencies

### Step 2: Build Swift App

Build the Swift app with Xcode:

```bash
xcodebuild \
  -project TalkyMcTalkface/TalkyMcTalkface.xcodeproj \
  -scheme TalkyMcTalkface \
  -configuration Release \
  build
```

Or use the unified script which handles the build location:

```bash
./scripts/build_distribution.sh --skip-python --skip-sign --skip-dmg
```

### Step 3: Integrate Python Backend

The Python backend must be copied into the app bundle:

```bash
cp -R dist/TalkyMcTalkface build/Release/TalkyMcTalkface.app/Contents/Resources/python-backend
```

The unified build script handles this automatically.

## Code Signing

### Sign the App Bundle

```bash
./scripts/sign_app.sh build/Release/TalkyMcTalkface.app
```

Or specify a signing identity:

```bash
./scripts/sign_app.sh build/Release/TalkyMcTalkface.app "Developer ID Application: Your Name (TEAMID)"
```

### What Gets Signed

The signing script signs in this order (inside-out):
1. All `.so` files (Python extensions)
2. All `.dylib` files (dynamic libraries)
3. Python backend executable
4. Frameworks
5. Main app bundle

### Verify Signature

```bash
# Basic verification
codesign --verify --verbose build/Release/TalkyMcTalkface.app

# Deep verification (all components)
codesign --verify --deep --verbose build/Release/TalkyMcTalkface.app

# Check Gatekeeper assessment
spctl --assess --type exec --verbose build/Release/TalkyMcTalkface.app
```

## Notarization

Notarization is required for Gatekeeper to allow your app to run without warnings.

### Submit for Notarization

```bash
./scripts/notarize_app.sh build/Release/TalkyMcTalkface.app
```

This script:
1. Creates a ZIP of the signed app
2. Submits to Apple's notarization service
3. Waits for approval (usually 5-15 minutes)
4. Staples the notarization ticket to the app

### Manual Notarization

If you prefer manual control:

```bash
# Create ZIP
ditto -c -k --keepParent build/Release/TalkyMcTalkface.app TalkyMcTalkface.zip

# Submit
xcrun notarytool submit TalkyMcTalkface.zip \
  --keychain-profile TalkyMcTalkface-notarize \
  --wait

# Staple ticket
xcrun stapler staple build/Release/TalkyMcTalkface.app
```

### Check Notarization Status

```bash
# Check submission history
xcrun notarytool history --keychain-profile TalkyMcTalkface-notarize

# Get log for a specific submission
xcrun notarytool log <submission-id> --keychain-profile TalkyMcTalkface-notarize
```

## DMG Creation

### Create DMG

```bash
./scripts/create_dmg.sh build/Release/TalkyMcTalkface.app
```

This creates `dist/TalkyMcTalkface.dmg` with:
- TalkyMcTalkface.app
- Applications folder alias
- Background image with install instructions
- Configured window appearance

### Notarize the DMG

For the best user experience, notarize the DMG as well:

```bash
xcrun notarytool submit dist/TalkyMcTalkface.dmg \
  --keychain-profile TalkyMcTalkface-notarize \
  --wait

xcrun stapler staple dist/TalkyMcTalkface.dmg
```

## Troubleshooting

### "Developer cannot be verified" Warning

This means the app is not notarized. Either:
- Run the notarization process
- Or users can right-click > Open to bypass (not recommended for distribution)

### Code Signing Errors

**"No identity found"**
- Ensure Developer ID certificate is in your keychain
- Check with: `security find-identity -v -p codesigning`

**"resource fork, Finder information, or similar detritus not allowed"**
- Clean extended attributes: `xattr -cr TalkyMcTalkface.app`

**"code object is not signed at all"**
- Re-run the signing script
- Ensure all nested binaries are signed first

### Notarization Errors

**"The signature of the binary is invalid"**
- Re-sign the app with `--force` flag
- Ensure hardened runtime is enabled

**"The executable does not have the hardened runtime enabled"**
- Sign with `--options runtime` (our scripts do this by default)

**"The signature does not include a secure timestamp"**
- Sign with `--timestamp` (our scripts do this by default)

### DMG Issues

**"DMG won't open"**
- Verify DMG signature: `codesign --verify dist/TalkyMcTalkface.dmg`
- Try creating without signing: comment out signing in create_dmg.sh

**"Background image not showing"**
- Ensure PIL is installed for background creation
- Or manually place a PNG at `resources/dmg-background.png`

### Python Backend Issues

**"Python executable not found"**
- Verify PyInstaller build completed: `ls dist/TalkyMcTalkface/`
- Check executable permissions: `chmod +x dist/TalkyMcTalkface/TalkyMcTalkface`

**"Server fails to start"**
- Run standalone test: `./dist/TalkyMcTalkface/TalkyMcTalkface`
- Check for missing dependencies in PyInstaller output

## Distribution Checklist

Before releasing:

- [ ] Build Python backend: `./scripts/build_python_backend.sh`
- [ ] Build Swift app: `xcodebuild ... build`
- [ ] Integrate backend into app bundle
- [ ] Sign app bundle: `./scripts/sign_app.sh`
- [ ] Notarize app: `./scripts/notarize_app.sh`
- [ ] Create DMG: `./scripts/create_dmg.sh`
- [ ] Notarize DMG (optional but recommended)
- [ ] Test on clean Mac without developer tools
- [ ] Verify Gatekeeper allows app to run
- [ ] Upload to distribution server

## Version Management

Update version numbers in:
- `TalkyMcTalkface/TalkyMcTalkface/Info.plist` (via Xcode project settings)
- `app/config.py` (APP_VERSION)

The version format follows semantic versioning: `MAJOR.MINOR.PATCH`
