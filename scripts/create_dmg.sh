#!/bin/bash
#
# DMG creation script for TalkyMcTalkface
#
# Creates a branded DMG distribution package with:
# - App icon
# - Applications folder alias for drag-to-install
# - Background image with install instructions
# - Configured window size and icon positions
# - Code signature on the DMG itself
#
# Usage:
#   ./scripts/create_dmg.sh <app_path> [output_dmg_path]
#
# Arguments:
#   app_path       - Path to the .app bundle
#   output_dmg_path - (Optional) Output path for DMG. Defaults to dist/TalkyMcTalkface.dmg
#
# Requirements:
#   - Xcode Command Line Tools
#   - Developer ID Application certificate (for signing the DMG)

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
OUTPUT_DMG="${2:-${PROJECT_ROOT}/dist/TalkyMcTalkface.dmg}"

# DMG settings
DMG_VOLUME_NAME="TalkyMcTalkface"
DMG_WINDOW_WIDTH=600
DMG_WINDOW_HEIGHT=400
DMG_ICON_SIZE=128
DMG_APP_X=150
DMG_APP_Y=200
DMG_APPS_X=450
DMG_APPS_Y=200

# Background image (will be created if not exists)
DMG_BACKGROUND="${PROJECT_ROOT}/resources/dmg-background.png"

# Signing identity
SIGNING_IDENTITY="${CODESIGN_IDENTITY:-}"

# -------------------------------------------------------------------
# Helper Functions
# -------------------------------------------------------------------

usage() {
    echo "Usage: $0 <app_path> [output_dmg_path]"
    echo ""
    echo "Arguments:"
    echo "  app_path        - Path to the .app bundle"
    echo "  output_dmg_path - Output path for DMG (default: dist/TalkyMcTalkface.dmg)"
    echo ""
    echo "Environment Variables:"
    echo "  CODESIGN_IDENTITY - Signing identity for DMG"
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

# Create a simple background image with install instructions
create_background_image() {
    local output_path="$1"
    local width="$2"
    local height="$3"

    log_info "Creating DMG background image..."

    # Create directory if needed
    mkdir -p "$(dirname "${output_path}")"

    # Use sips to create a simple colored background, then use Python for text
    # First create a blank image with a gradient-like color
    local temp_png="/tmp/dmg_bg_temp.png"

    # Check if Python with PIL is available for creating background
    if python3 -c "from PIL import Image, ImageDraw, ImageFont" 2>/dev/null; then
        python3 << EOF
from PIL import Image, ImageDraw, ImageFont

# Create image with gradient
width, height = ${width}, ${height}
img = Image.new('RGB', (width, height))

# Create a subtle gradient from dark to light blue-gray
for y in range(height):
    r = int(45 + (y / height) * 15)
    g = int(52 + (y / height) * 18)
    b = int(65 + (y / height) * 25)
    for x in range(width):
        img.putpixel((x, y), (r, g, b))

draw = ImageDraw.Draw(img)

# Add install instructions text at bottom
try:
    # Try to use a system font
    font = ImageFont.truetype('/System/Library/Fonts/SFCompact.ttf', 16)
except:
    try:
        font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 16)
    except:
        font = ImageFont.load_default()

text = "Drag TalkyMcTalkface to Applications to install"
bbox = draw.textbbox((0, 0), text, font=font)
text_width = bbox[2] - bbox[0]
text_x = (width - text_width) // 2
text_y = height - 50

# Draw text with shadow for visibility
draw.text((text_x + 1, text_y + 1), text, fill=(30, 30, 30), font=font)
draw.text((text_x, text_y), text, fill=(180, 180, 180), font=font)

img.save('${output_path}')
print("Background image created with PIL")
EOF
    else
        # Fallback: create a simple gray background using sips
        log_warn "PIL not available, creating simple background"

        # Create a simple solid color PNG using convert if available
        if command -v convert &>/dev/null; then
            convert -size ${width}x${height} xc:'#2d3441' \
                -gravity south -fill '#b4b4b4' -pointsize 16 \
                -annotate +0+30 "Drag TalkyMcTalkface to Applications to install" \
                "${output_path}"
        else
            # Last resort: use Python with basic image creation
            python3 << EOF
# Simple PPM creation without PIL
width, height = ${width}, ${height}
with open('${temp_png}', 'w') as f:
    f.write(f'P3\n{width} {height}\n255\n')
    for y in range(height):
        for x in range(width):
            r = int(45 + (y / height) * 15)
            g = int(52 + (y / height) * 18)
            b = int(65 + (y / height) * 25)
            f.write(f'{r} {g} {b}\n')
EOF
            # Convert PPM to PNG using sips
            sips -s format png "${temp_png}" --out "${output_path}" 2>/dev/null || {
                log_warn "Could not create background image, DMG will have no background"
                return 1
            }
        fi
    fi

    log_info "Background image created: ${output_path}"
}

# -------------------------------------------------------------------
# Main Script
# -------------------------------------------------------------------

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}TalkyMcTalkface DMG Creation${NC}"
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

# Create output directory
mkdir -p "$(dirname "${OUTPUT_DMG}")"

# Remove existing DMG
rm -f "${OUTPUT_DMG}"

log_info "Creating DMG for: ${APP_PATH}"
log_info "Output: ${OUTPUT_DMG}"
echo ""

# -------------------------------------------------------------------
# Step 1: Create background image if not exists
# -------------------------------------------------------------------
if [[ ! -f "${DMG_BACKGROUND}" ]]; then
    log_info "Step 1: Creating background image..."
    create_background_image "${DMG_BACKGROUND}" "${DMG_WINDOW_WIDTH}" "${DMG_WINDOW_HEIGHT}" || true
else
    log_info "Step 1: Using existing background image: ${DMG_BACKGROUND}"
fi
echo ""

# -------------------------------------------------------------------
# Step 2: Create temporary DMG structure
# -------------------------------------------------------------------
log_info "Step 2: Creating DMG structure..."

TEMP_DIR=$(mktemp -d)
DMG_TEMP="${TEMP_DIR}/dmg_contents"
mkdir -p "${DMG_TEMP}"

# Copy app to temp directory
log_info "Copying app bundle..."
cp -R "${APP_PATH}" "${DMG_TEMP}/"

# Create Applications symlink
log_info "Creating Applications alias..."
ln -s /Applications "${DMG_TEMP}/Applications"

# Copy background image if exists
if [[ -f "${DMG_BACKGROUND}" ]]; then
    mkdir -p "${DMG_TEMP}/.background"
    cp "${DMG_BACKGROUND}" "${DMG_TEMP}/.background/background.png"
fi

echo ""

# -------------------------------------------------------------------
# Step 3: Create temporary read-write DMG
# -------------------------------------------------------------------
log_info "Step 3: Creating temporary DMG..."

TEMP_DMG="${TEMP_DIR}/${DMG_VOLUME_NAME}_temp.dmg"

# Calculate size needed (app size + 50MB buffer)
APP_SIZE=$(du -sm "${APP_PATH}" | cut -f1)
DMG_SIZE=$((APP_SIZE + 50))

# Create read-write DMG
hdiutil create \
    -srcfolder "${DMG_TEMP}" \
    -volname "${DMG_VOLUME_NAME}" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size "${DMG_SIZE}m" \
    "${TEMP_DMG}"

echo ""

# -------------------------------------------------------------------
# Step 4: Mount and customize DMG appearance
# -------------------------------------------------------------------
log_info "Step 4: Customizing DMG appearance..."

# Mount the DMG
MOUNT_POINT="/Volumes/${DMG_VOLUME_NAME}"

# Unmount if already mounted
if [[ -d "${MOUNT_POINT}" ]]; then
    hdiutil detach "${MOUNT_POINT}" -force 2>/dev/null || true
fi

hdiutil attach "${TEMP_DMG}" -mountpoint "${MOUNT_POINT}" -nobrowse

# Wait for mount
sleep 2

# Set background and icon positions using AppleScript
log_info "Setting window appearance..."

osascript << EOF
tell application "Finder"
    tell disk "${DMG_VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {100, 100, $((100 + DMG_WINDOW_WIDTH)), $((100 + DMG_WINDOW_HEIGHT))}

        set theViewOptions to icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to ${DMG_ICON_SIZE}

        -- Set background if available
        try
            set background picture of theViewOptions to file ".background:background.png"
        end try

        -- Position icons
        set position of item "${APP_NAME}.app" of container window to {${DMG_APP_X}, ${DMG_APP_Y}}
        set position of item "Applications" of container window to {${DMG_APPS_X}, ${DMG_APPS_Y}}

        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

# Set volume icon if app has one
if [[ -f "${APP_PATH}/Contents/Resources/AppIcon.icns" ]]; then
    log_info "Setting volume icon..."
    cp "${APP_PATH}/Contents/Resources/AppIcon.icns" "${MOUNT_POINT}/.VolumeIcon.icns"
    SetFile -c icnC "${MOUNT_POINT}/.VolumeIcon.icns" 2>/dev/null || true
    SetFile -a C "${MOUNT_POINT}" 2>/dev/null || true
fi

# Sync and unmount
sync
hdiutil detach "${MOUNT_POINT}"

echo ""

# -------------------------------------------------------------------
# Step 5: Convert to compressed read-only DMG
# -------------------------------------------------------------------
log_info "Step 5: Creating final compressed DMG..."

hdiutil convert "${TEMP_DMG}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${OUTPUT_DMG}"

echo ""

# -------------------------------------------------------------------
# Step 6: Sign the DMG (optional but recommended)
# -------------------------------------------------------------------
log_info "Step 6: Signing DMG..."

# Discover signing identity if not provided
if [[ -z "${SIGNING_IDENTITY}" ]]; then
    SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/' || true)
fi

if [[ -n "${SIGNING_IDENTITY}" ]]; then
    log_info "Signing with: ${SIGNING_IDENTITY}"
    codesign --force --sign "${SIGNING_IDENTITY}" "${OUTPUT_DMG}"

    # Verify signature
    if codesign --verify "${OUTPUT_DMG}"; then
        log_info "DMG signed successfully"
    else
        log_warn "DMG signature verification failed"
    fi
else
    log_warn "No signing identity found. DMG will not be signed."
    log_info "Set CODESIGN_IDENTITY environment variable to sign the DMG"
fi

echo ""

# -------------------------------------------------------------------
# Cleanup
# -------------------------------------------------------------------
log_info "Cleaning up temporary files..."
rm -rf "${TEMP_DIR}"

# -------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}DMG Creation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Get DMG size
DMG_FINAL_SIZE=$(du -h "${OUTPUT_DMG}" | cut -f1)

echo "Output: ${OUTPUT_DMG}"
echo "Size: ${DMG_FINAL_SIZE}"
echo ""
echo "To notarize the DMG:"
echo "  xcrun notarytool submit ${OUTPUT_DMG} --keychain-profile TalkyMcTalkface-notarize --wait"
echo ""
echo "To staple after notarization:"
echo "  xcrun stapler staple ${OUTPUT_DMG}"
echo ""

exit 0
