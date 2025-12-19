#!/bin/bash
#
# Code signing script for TalkyMcTalkface
#
# Signs the .app bundle with a Developer ID certificate.
# This script handles:
# - Signing all embedded frameworks and executables
# - Signing the main app bundle
# - Verifying the signature
#
# Usage:
#   ./scripts/sign_app.sh <app_path> [signing_identity]
#
# Arguments:
#   app_path          - Path to the .app bundle
#   signing_identity  - (Optional) Signing identity. Defaults to discovering
#                       the first "Developer ID Application" certificate.
#
# Environment Variables:
#   CODESIGN_IDENTITY - Alternative to passing signing_identity argument
#   ENTITLEMENTS_PATH - Path to entitlements file (default: auto-detected)
#
# Requirements:
#   - Xcode Command Line Tools
#   - Developer ID Application certificate in keychain
#   - For notarization: Developer ID Installer certificate (for DMG)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Parse arguments
APP_PATH="${1:-}"
SIGNING_IDENTITY="${2:-${CODESIGN_IDENTITY:-}}"

# Default entitlements path
ENTITLEMENTS_PATH="${ENTITLEMENTS_PATH:-${PROJECT_ROOT}/TalkyMcTalkface/TalkyMcTalkface/TalkyMcTalkface.entitlements}"

# -------------------------------------------------------------------
# Helper Functions
# -------------------------------------------------------------------

usage() {
    echo "Usage: $0 <app_path> [signing_identity]"
    echo ""
    echo "Arguments:"
    echo "  app_path          Path to the .app bundle to sign"
    echo "  signing_identity  Signing identity (default: auto-discover)"
    echo ""
    echo "Environment Variables:"
    echo "  CODESIGN_IDENTITY - Signing identity"
    echo "  ENTITLEMENTS_PATH - Path to entitlements file"
    echo ""
    echo "Examples:"
    echo "  $0 ./dist/TalkyMcTalkface.app"
    echo "  $0 ./dist/TalkyMcTalkface.app 'Developer ID Application: Your Name (TEAMID)'"
    exit 1
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

# Discover Developer ID Application certificate
discover_signing_identity() {
    # List available signing identities
    local identity
    identity=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/')

    if [[ -z "${identity}" ]]; then
        log_error "No Developer ID Application certificate found in keychain"
        log_info "To create a certificate:"
        log_info "  1. Go to developer.apple.com/account"
        log_info "  2. Navigate to Certificates, Identifiers & Profiles"
        log_info "  3. Create a Developer ID Application certificate"
        log_info "  4. Download and install in Keychain Access"
        return 1
    fi

    echo "${identity}"
}

# Sign a single item (file or bundle)
sign_item() {
    local item_path="$1"
    local identity="$2"
    local entitlements="$3"
    local options="$4"

    local entitlements_arg=""
    if [[ -n "${entitlements}" && -f "${entitlements}" ]]; then
        entitlements_arg="--entitlements ${entitlements}"
    fi

    log_info "Signing: ${item_path}"
    codesign --force --sign "${identity}" \
        --timestamp \
        --options "${options:-runtime}" \
        ${entitlements_arg} \
        "${item_path}"
}

# Verify a signature
verify_signature() {
    local item_path="$1"

    log_info "Verifying: ${item_path}"
    if ! codesign --verify --verbose=2 "${item_path}"; then
        log_error "Signature verification failed for: ${item_path}"
        return 1
    fi

    # Also check with strict validation
    if ! codesign --verify --strict "${item_path}"; then
        log_error "Strict signature verification failed for: ${item_path}"
        return 1
    fi
}

# -------------------------------------------------------------------
# Main Script
# -------------------------------------------------------------------

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}TalkyMcTalkface Code Signing${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Validate arguments
if [[ -z "${APP_PATH}" ]]; then
    log_error "No app path provided"
    usage
fi

if [[ ! -d "${APP_PATH}" ]]; then
    log_error "App bundle not found: ${APP_PATH}"
    exit 1
fi

# Resolve to absolute path
APP_PATH="$(cd "$(dirname "${APP_PATH}")" && pwd)/$(basename "${APP_PATH}")"

# Discover signing identity if not provided
if [[ -z "${SIGNING_IDENTITY}" ]]; then
    log_info "Discovering signing identity..."
    SIGNING_IDENTITY=$(discover_signing_identity) || exit 1
fi

log_info "Using signing identity: ${SIGNING_IDENTITY}"
log_info "App path: ${APP_PATH}"
echo ""

# -------------------------------------------------------------------
# Step 1: Sign embedded content (inside-out)
# -------------------------------------------------------------------
log_info "Step 1: Signing embedded content..."

# Sign any frameworks
FRAMEWORKS_DIR="${APP_PATH}/Contents/Frameworks"
if [[ -d "${FRAMEWORKS_DIR}" ]]; then
    log_info "Signing frameworks in ${FRAMEWORKS_DIR}"
    find "${FRAMEWORKS_DIR}" -name "*.framework" -type d | while read -r framework; do
        sign_item "${framework}" "${SIGNING_IDENTITY}" "" "runtime"
    done

    # Sign any dylibs
    find "${FRAMEWORKS_DIR}" -name "*.dylib" -type f | while read -r dylib; do
        sign_item "${dylib}" "${SIGNING_IDENTITY}" "" "runtime"
    done
fi

# Sign Python backend if present
PYTHON_BACKEND="${APP_PATH}/Contents/Resources/python-backend"
if [[ -d "${PYTHON_BACKEND}" ]]; then
    log_info "Signing Python backend..."

    # Sign the main executable
    if [[ -f "${PYTHON_BACKEND}/TalkyMcTalkface" ]]; then
        sign_item "${PYTHON_BACKEND}/TalkyMcTalkface" "${SIGNING_IDENTITY}" "" "runtime"
    fi

    # Sign all .so files (Python extensions)
    find "${PYTHON_BACKEND}" -name "*.so" -type f | while read -r so_file; do
        sign_item "${so_file}" "${SIGNING_IDENTITY}" "" "runtime"
    done

    # Sign all dylibs in the backend
    find "${PYTHON_BACKEND}" -name "*.dylib" -type f | while read -r dylib; do
        sign_item "${dylib}" "${SIGNING_IDENTITY}" "" "runtime"
    done
fi

# Sign any other executables in Resources
RESOURCES_DIR="${APP_PATH}/Contents/Resources"
if [[ -d "${RESOURCES_DIR}" ]]; then
    # Find executable files (but not Python scripts or other text files)
    find "${RESOURCES_DIR}" -type f -perm +111 | while read -r exec_file; do
        # Skip if not a Mach-O binary
        if file "${exec_file}" | grep -q "Mach-O"; then
            sign_item "${exec_file}" "${SIGNING_IDENTITY}" "" "runtime"
        fi
    done
fi

echo ""

# -------------------------------------------------------------------
# Step 2: Sign the main app bundle
# -------------------------------------------------------------------
log_info "Step 2: Signing main app bundle..."

if [[ -f "${ENTITLEMENTS_PATH}" ]]; then
    log_info "Using entitlements: ${ENTITLEMENTS_PATH}"
    sign_item "${APP_PATH}" "${SIGNING_IDENTITY}" "${ENTITLEMENTS_PATH}" "runtime"
else
    log_warn "No entitlements file found, signing without entitlements"
    sign_item "${APP_PATH}" "${SIGNING_IDENTITY}" "" "runtime"
fi

echo ""

# -------------------------------------------------------------------
# Step 3: Verify signatures
# -------------------------------------------------------------------
log_info "Step 3: Verifying signatures..."

verify_signature "${APP_PATH}"

# Deep verification
log_info "Performing deep verification..."
if ! codesign --verify --deep --verbose=2 "${APP_PATH}"; then
    log_error "Deep signature verification failed"
    exit 1
fi

echo ""

# -------------------------------------------------------------------
# Step 4: Check Gatekeeper assessment (optional)
# -------------------------------------------------------------------
log_info "Step 4: Checking Gatekeeper assessment..."

# Note: This requires notarization to pass fully
spctl_result=$(spctl --assess --type exec --verbose "${APP_PATH}" 2>&1) || true

if echo "${spctl_result}" | grep -q "accepted"; then
    log_info "Gatekeeper: accepted"
elif echo "${spctl_result}" | grep -q "rejected"; then
    log_warn "Gatekeeper: rejected (notarization may be required)"
    log_warn "Result: ${spctl_result}"
else
    log_warn "Gatekeeper assessment result: ${spctl_result}"
fi

echo ""

# -------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Code Signing Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Signed app: ${APP_PATH}"
echo ""
echo "Next steps:"
echo "  1. Notarize the app: ./scripts/notarize_app.sh ${APP_PATH}"
echo "  2. Create DMG: ./scripts/create_dmg.sh ${APP_PATH}"
echo ""

exit 0
