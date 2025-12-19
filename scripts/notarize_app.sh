#!/bin/bash
#
# Notarization script for TalkyMcTalkface
#
# Submits the signed .app bundle to Apple's notarization service,
# waits for completion, and staples the ticket.
#
# Usage:
#   ./scripts/notarize_app.sh <app_path>
#
# Arguments:
#   app_path - Path to the signed .app bundle
#
# Environment Variables (required):
#   APPLE_ID            - Your Apple ID email
#   APPLE_TEAM_ID       - Your Apple Developer Team ID
#   APPLE_APP_PASSWORD  - App-specific password for notarization
#                         (Create at appleid.apple.com > App-Specific Passwords)
#
# Requirements:
#   - Xcode 13+ with notarytool (or xcrun altool for older Xcode)
#   - Signed .app bundle
#   - Apple Developer account

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

# Notarization credentials from environment
APPLE_ID="${APPLE_ID:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
APPLE_APP_PASSWORD="${APPLE_APP_PASSWORD:-}"

# Keychain profile name (for stored credentials)
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-TalkyMcTalkface-notarize}"

# -------------------------------------------------------------------
# Helper Functions
# -------------------------------------------------------------------

usage() {
    echo "Usage: $0 <app_path>"
    echo ""
    echo "Arguments:"
    echo "  app_path - Path to the signed .app bundle"
    echo ""
    echo "Environment Variables (required unless using keychain profile):"
    echo "  APPLE_ID           - Your Apple ID email"
    echo "  APPLE_TEAM_ID      - Your Apple Developer Team ID"
    echo "  APPLE_APP_PASSWORD - App-specific password"
    echo ""
    echo "Or use stored credentials:"
    echo "  KEYCHAIN_PROFILE   - Name of stored keychain profile"
    echo ""
    echo "To store credentials in keychain:"
    echo "  xcrun notarytool store-credentials TalkyMcTalkface-notarize \\"
    echo "    --apple-id your@email.com \\"
    echo "    --team-id YOURTEAMID \\"
    echo "    --password your-app-specific-password"
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

# Check if notarytool is available (Xcode 13+)
check_notarytool() {
    if xcrun notarytool --version &>/dev/null; then
        return 0
    fi
    return 1
}

# Check if credentials are available
check_credentials() {
    # First check if keychain profile exists
    if xcrun notarytool info --keychain-profile "${KEYCHAIN_PROFILE}" dummy 2>&1 | grep -q "no-record"; then
        # Profile exists but no record (expected error for dummy)
        return 0
    fi

    # Check if individual credentials are set
    if [[ -n "${APPLE_ID}" && -n "${APPLE_TEAM_ID}" && -n "${APPLE_APP_PASSWORD}" ]]; then
        return 0
    fi

    return 1
}

# Get notarytool auth arguments
get_auth_args() {
    # Try keychain profile first
    if xcrun notarytool history --keychain-profile "${KEYCHAIN_PROFILE}" &>/dev/null 2>&1; then
        echo "--keychain-profile ${KEYCHAIN_PROFILE}"
    elif [[ -n "${APPLE_ID}" && -n "${APPLE_TEAM_ID}" && -n "${APPLE_APP_PASSWORD}" ]]; then
        echo "--apple-id ${APPLE_ID} --team-id ${APPLE_TEAM_ID} --password ${APPLE_APP_PASSWORD}"
    else
        return 1
    fi
}

# -------------------------------------------------------------------
# Main Script
# -------------------------------------------------------------------

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}TalkyMcTalkface Notarization${NC}"
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
APP_NAME=$(basename "${APP_PATH}" .app)

log_info "App path: ${APP_PATH}"

# Check for notarytool
if ! check_notarytool; then
    log_error "notarytool not found. Xcode 13+ is required."
    log_info "Alternatively, update Xcode Command Line Tools:"
    log_info "  xcode-select --install"
    exit 1
fi

# Check credentials
AUTH_ARGS=$(get_auth_args) || {
    log_error "No notarization credentials found"
    log_info ""
    log_info "Option 1: Set environment variables:"
    log_info "  export APPLE_ID='your@email.com'"
    log_info "  export APPLE_TEAM_ID='YOURTEAMID'"
    log_info "  export APPLE_APP_PASSWORD='xxxx-xxxx-xxxx-xxxx'"
    log_info ""
    log_info "Option 2: Store credentials in keychain:"
    log_info "  xcrun notarytool store-credentials ${KEYCHAIN_PROFILE} \\"
    log_info "    --apple-id your@email.com \\"
    log_info "    --team-id YOURTEAMID \\"
    log_info "    --password your-app-specific-password"
    exit 1
}

# -------------------------------------------------------------------
# Step 1: Verify the app is signed
# -------------------------------------------------------------------
log_info "Step 1: Verifying code signature..."

if ! codesign --verify --deep "${APP_PATH}"; then
    log_error "App is not properly signed. Run sign_app.sh first."
    exit 1
fi

log_info "Signature verified."
echo ""

# -------------------------------------------------------------------
# Step 2: Create ZIP for notarization
# -------------------------------------------------------------------
log_info "Step 2: Creating ZIP archive for notarization..."

ZIP_PATH="${PROJECT_ROOT}/dist/${APP_NAME}-notarize.zip"
mkdir -p "$(dirname "${ZIP_PATH}")"

# Remove existing zip if present
rm -f "${ZIP_PATH}"

# Create zip using ditto (preserves code signatures and metadata)
ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"

log_info "Created: ${ZIP_PATH}"
echo ""

# -------------------------------------------------------------------
# Step 3: Submit for notarization
# -------------------------------------------------------------------
log_info "Step 3: Submitting for notarization..."
log_info "This may take several minutes..."

# Submit and capture the submission ID
SUBMIT_OUTPUT=$(xcrun notarytool submit "${ZIP_PATH}" ${AUTH_ARGS} --wait 2>&1)
SUBMIT_EXIT_CODE=$?

echo "${SUBMIT_OUTPUT}"

# Extract submission ID from output
SUBMISSION_ID=$(echo "${SUBMIT_OUTPUT}" | grep -o "id: [a-f0-9-]*" | head -1 | cut -d' ' -f2)

if [[ ${SUBMIT_EXIT_CODE} -ne 0 ]]; then
    log_error "Notarization submission failed"

    if [[ -n "${SUBMISSION_ID}" ]]; then
        log_info "Getting detailed log for submission ${SUBMISSION_ID}..."
        xcrun notarytool log "${SUBMISSION_ID}" ${AUTH_ARGS} || true
    fi

    exit 1
fi

# Check status from output
if echo "${SUBMIT_OUTPUT}" | grep -q "status: Accepted"; then
    log_info "Notarization successful!"
elif echo "${SUBMIT_OUTPUT}" | grep -q "status: Invalid"; then
    log_error "Notarization rejected"
    if [[ -n "${SUBMISSION_ID}" ]]; then
        log_info "Getting detailed log..."
        xcrun notarytool log "${SUBMISSION_ID}" ${AUTH_ARGS} || true
    fi
    exit 1
else
    log_warn "Unexpected status. Check output above."
fi

echo ""

# -------------------------------------------------------------------
# Step 4: Staple the notarization ticket
# -------------------------------------------------------------------
log_info "Step 4: Stapling notarization ticket..."

if ! xcrun stapler staple "${APP_PATH}"; then
    log_error "Failed to staple notarization ticket"
    log_info "The app is notarized but the ticket is not stapled."
    log_info "Users may experience delays while macOS verifies online."
    exit 1
fi

log_info "Ticket stapled successfully!"
echo ""

# -------------------------------------------------------------------
# Step 5: Verify stapled ticket
# -------------------------------------------------------------------
log_info "Step 5: Verifying stapled ticket..."

if ! xcrun stapler validate "${APP_PATH}"; then
    log_warn "Stapler validation returned an error, but this may be normal"
fi

# Check with spctl
spctl_result=$(spctl --assess --type exec --verbose "${APP_PATH}" 2>&1) || true

if echo "${spctl_result}" | grep -q "accepted"; then
    log_info "Gatekeeper: accepted"
    log_info "The app will run on any Mac without security warnings!"
else
    log_warn "Gatekeeper result: ${spctl_result}"
fi

echo ""

# -------------------------------------------------------------------
# Cleanup
# -------------------------------------------------------------------
log_info "Cleaning up..."
rm -f "${ZIP_PATH}"

# -------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Notarization Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Notarized app: ${APP_PATH}"
if [[ -n "${SUBMISSION_ID}" ]]; then
    echo "Submission ID: ${SUBMISSION_ID}"
fi
echo ""
echo "Next steps:"
echo "  Create DMG: ./scripts/create_dmg.sh ${APP_PATH}"
echo ""

exit 0
