#!/bin/bash
#
# Unified build and distribution script for TalkyMcTalkface
#
# This script performs the complete build and distribution workflow:
# 1. Build Python backend with PyInstaller
# 2. Build Swift app with Xcode
# 3. Integrate Python backend into .app bundle
# 4. Sign the complete .app bundle
# 5. Notarize with Apple (optional, requires credentials)
# 6. Create DMG distribution package
#
# Usage:
#   ./scripts/build_distribution.sh [options]
#
# Options:
#   --skip-python       Skip Python backend build (use existing)
#   --skip-swift        Skip Swift app build (use existing)
#   --skip-sign         Skip code signing
#   --skip-notarize     Skip notarization (default if no credentials)
#   --skip-dmg          Skip DMG creation
#   --release           Build release configuration (default)
#   --debug             Build debug configuration
#   --help              Show this help message
#
# Environment Variables:
#   CODESIGN_IDENTITY   - Code signing identity
#   APPLE_ID            - Apple ID for notarization
#   APPLE_TEAM_ID       - Apple Team ID for notarization
#   APPLE_APP_PASSWORD  - App-specific password for notarization
#
# Requirements:
#   - Python 3.11+ with PyInstaller and dependencies
#   - Xcode 15+ with command line tools
#   - Developer ID certificates (for signing)
#   - Apple Developer account (for notarization)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Default options
SKIP_PYTHON=false
SKIP_SWIFT=false
SKIP_SIGN=false
SKIP_NOTARIZE=false
SKIP_DMG=false
BUILD_CONFIG="Release"

# Output paths
DIST_DIR="${PROJECT_ROOT}/dist"
PYTHON_DIST="${DIST_DIR}/TalkyMcTalkface"
SWIFT_BUILD_DIR="${PROJECT_ROOT}/build"
XCODE_PROJECT="${PROJECT_ROOT}/TalkyMcTalkface/TalkyMcTalkface.xcodeproj"
APP_NAME="TalkyMcTalkface"
APP_BUNDLE="${SWIFT_BUILD_DIR}/${BUILD_CONFIG}/${APP_NAME}.app"
FINAL_DMG="${DIST_DIR}/${APP_NAME}.dmg"

# -------------------------------------------------------------------
# Helper Functions
# -------------------------------------------------------------------

usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --skip-python       Skip Python backend build"
    echo "  --skip-swift        Skip Swift app build"
    echo "  --skip-sign         Skip code signing"
    echo "  --skip-notarize     Skip notarization"
    echo "  --skip-dmg          Skip DMG creation"
    echo "  --release           Build release configuration (default)"
    echo "  --debug             Build debug configuration"
    echo "  --help              Show this help message"
    exit 0
}

log_step() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_dependencies() {
    local missing=0

    # Check Python
    if ! command -v python3 &>/dev/null; then
        log_error "Python 3 not found"
        missing=1
    fi

    # Check xcodebuild
    if ! command -v xcodebuild &>/dev/null; then
        log_error "xcodebuild not found. Install Xcode Command Line Tools."
        missing=1
    fi

    # Check codesign
    if ! command -v codesign &>/dev/null; then
        log_error "codesign not found. Install Xcode Command Line Tools."
        missing=1
    fi

    # Check hdiutil
    if ! command -v hdiutil &>/dev/null; then
        log_error "hdiutil not found. This should be available on macOS."
        missing=1
    fi

    if [[ ${missing} -eq 1 ]]; then
        exit 1
    fi
}

# -------------------------------------------------------------------
# Parse Arguments
# -------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-python)
            SKIP_PYTHON=true
            shift
            ;;
        --skip-swift)
            SKIP_SWIFT=true
            shift
            ;;
        --skip-sign)
            SKIP_SIGN=true
            shift
            ;;
        --skip-notarize)
            SKIP_NOTARIZE=true
            shift
            ;;
        --skip-dmg)
            SKIP_DMG=true
            shift
            ;;
        --release)
            BUILD_CONFIG="Release"
            shift
            ;;
        --debug)
            BUILD_CONFIG="Debug"
            shift
            ;;
        --help|-h)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Update paths based on config
APP_BUNDLE="${SWIFT_BUILD_DIR}/${BUILD_CONFIG}/${APP_NAME}.app"

# -------------------------------------------------------------------
# Main Script
# -------------------------------------------------------------------

echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          TalkyMcTalkface Distribution Build               ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Configuration: ${BUILD_CONFIG}"
echo "Project root: ${PROJECT_ROOT}"
echo ""

# Check dependencies
log_info "Checking dependencies..."
check_dependencies
log_info "All dependencies found."

# Create dist directory
mkdir -p "${DIST_DIR}"

# -------------------------------------------------------------------
# Step 1: Build Python Backend
# -------------------------------------------------------------------

if [[ "${SKIP_PYTHON}" == "true" ]]; then
    log_step "Step 1: Skipping Python backend build"
    if [[ ! -d "${PYTHON_DIST}" ]]; then
        log_error "Python backend not found at ${PYTHON_DIST}"
        log_error "Remove --skip-python flag or build manually"
        exit 1
    fi
else
    log_step "Step 1: Building Python Backend"

    cd "${PROJECT_ROOT}"

    # Run the Python build script
    "${SCRIPT_DIR}/build_python_backend.sh" --skip-test

    if [[ ! -d "${PYTHON_DIST}" ]]; then
        log_error "Python backend build failed"
        exit 1
    fi

    log_info "Python backend built successfully"
fi

# -------------------------------------------------------------------
# Step 2: Build Swift App
# -------------------------------------------------------------------

if [[ "${SKIP_SWIFT}" == "true" ]]; then
    log_step "Step 2: Skipping Swift app build"
    if [[ ! -d "${APP_BUNDLE}" ]]; then
        log_error "Swift app not found at ${APP_BUNDLE}"
        log_error "Remove --skip-swift flag or build manually"
        exit 1
    fi
else
    log_step "Step 2: Building Swift App"

    cd "${PROJECT_ROOT}"

    # Clean previous build
    if [[ -d "${SWIFT_BUILD_DIR}" ]]; then
        log_info "Cleaning previous build..."
        rm -rf "${SWIFT_BUILD_DIR}"
    fi

    # Build with xcodebuild
    log_info "Building ${BUILD_CONFIG} configuration..."

    xcodebuild \
        -project "${XCODE_PROJECT}" \
        -scheme "${APP_NAME}" \
        -configuration "${BUILD_CONFIG}" \
        -derivedDataPath "${SWIFT_BUILD_DIR}" \
        SYMROOT="${SWIFT_BUILD_DIR}" \
        build

    # Find the built app (xcodebuild puts it in a nested structure)
    BUILT_APP=$(find "${SWIFT_BUILD_DIR}" -name "${APP_NAME}.app" -type d | head -1)

    if [[ -z "${BUILT_APP}" || ! -d "${BUILT_APP}" ]]; then
        log_error "Swift app build failed - app bundle not found"
        exit 1
    fi

    # Move to expected location if needed
    if [[ "${BUILT_APP}" != "${APP_BUNDLE}" ]]; then
        mkdir -p "$(dirname "${APP_BUNDLE}")"
        rm -rf "${APP_BUNDLE}"
        cp -R "${BUILT_APP}" "${APP_BUNDLE}"
    fi

    log_info "Swift app built successfully: ${APP_BUNDLE}"
fi

# -------------------------------------------------------------------
# Step 3: Integrate Python Backend
# -------------------------------------------------------------------

log_step "Step 3: Integrating Python Backend"

RESOURCES_DIR="${APP_BUNDLE}/Contents/Resources"
PYTHON_DEST="${RESOURCES_DIR}/python-backend"

# Remove existing Python backend if present
if [[ -d "${PYTHON_DEST}" ]]; then
    log_info "Removing existing Python backend..."
    rm -rf "${PYTHON_DEST}"
fi

# Copy Python backend
log_info "Copying Python backend to app bundle..."
mkdir -p "${RESOURCES_DIR}"
cp -R "${PYTHON_DIST}" "${PYTHON_DEST}"

# Verify the executable exists
if [[ ! -f "${PYTHON_DEST}/TalkyMcTalkface" ]]; then
    log_error "Python executable not found after copy"
    exit 1
fi

# Ensure executable permissions
chmod +x "${PYTHON_DEST}/TalkyMcTalkface"

log_info "Python backend integrated successfully"

# -------------------------------------------------------------------
# Step 4: Code Signing
# -------------------------------------------------------------------

if [[ "${SKIP_SIGN}" == "true" ]]; then
    log_step "Step 4: Skipping Code Signing"
else
    log_step "Step 4: Code Signing"

    "${SCRIPT_DIR}/sign_app.sh" "${APP_BUNDLE}"

    if [[ $? -ne 0 ]]; then
        log_error "Code signing failed"
        exit 1
    fi

    log_info "Code signing completed"
fi

# -------------------------------------------------------------------
# Step 5: Notarization
# -------------------------------------------------------------------

if [[ "${SKIP_NOTARIZE}" == "true" ]]; then
    log_step "Step 5: Skipping Notarization"
else
    log_step "Step 5: Notarization"

    # Check if credentials are available
    HAS_CREDENTIALS=false

    if [[ -n "${APPLE_ID}" && -n "${APPLE_TEAM_ID}" && -n "${APPLE_APP_PASSWORD}" ]]; then
        HAS_CREDENTIALS=true
    elif xcrun notarytool history --keychain-profile TalkyMcTalkface-notarize &>/dev/null 2>&1; then
        HAS_CREDENTIALS=true
    fi

    if [[ "${HAS_CREDENTIALS}" == "true" ]]; then
        "${SCRIPT_DIR}/notarize_app.sh" "${APP_BUNDLE}"

        if [[ $? -ne 0 ]]; then
            log_warn "Notarization failed, continuing without notarization"
        else
            log_info "Notarization completed"
        fi
    else
        log_warn "No notarization credentials found, skipping"
        log_info "To enable notarization, set environment variables:"
        log_info "  APPLE_ID, APPLE_TEAM_ID, APPLE_APP_PASSWORD"
        log_info "Or store credentials in keychain:"
        log_info "  xcrun notarytool store-credentials TalkyMcTalkface-notarize"
    fi
fi

# -------------------------------------------------------------------
# Step 6: Create DMG
# -------------------------------------------------------------------

if [[ "${SKIP_DMG}" == "true" ]]; then
    log_step "Step 6: Skipping DMG Creation"
else
    log_step "Step 6: Creating DMG"

    "${SCRIPT_DIR}/create_dmg.sh" "${APP_BUNDLE}" "${FINAL_DMG}"

    if [[ $? -ne 0 ]]; then
        log_error "DMG creation failed"
        exit 1
    fi

    log_info "DMG created successfully"
fi

# -------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    Build Complete!                         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo "Build outputs:"
echo ""

if [[ -d "${APP_BUNDLE}" ]]; then
    APP_SIZE=$(du -sh "${APP_BUNDLE}" | cut -f1)
    echo "  App bundle: ${APP_BUNDLE}"
    echo "  Size: ${APP_SIZE}"
    echo ""
fi

if [[ -f "${FINAL_DMG}" ]]; then
    DMG_SIZE=$(du -h "${FINAL_DMG}" | cut -f1)
    echo "  DMG: ${FINAL_DMG}"
    echo "  Size: ${DMG_SIZE}"
    echo ""
fi

# Check signature status
echo "Signature status:"
if codesign --verify "${APP_BUNDLE}" 2>/dev/null; then
    echo "  App signed: Yes"

    if xcrun stapler validate "${APP_BUNDLE}" 2>/dev/null; then
        echo "  Notarized: Yes"
    else
        echo "  Notarized: No"
    fi
else
    echo "  App signed: No"
fi

echo ""
echo "Distribution checklist:"
echo "  [ ] Test the DMG on a clean Mac"
echo "  [ ] Verify Gatekeeper allows the app to run"
echo "  [ ] Upload to your distribution server"
echo ""

exit 0
