#!/bin/bash
#
# Build script for TalkyMcTalkface Python backend
#
# This script:
# 1. Installs/verifies PyInstaller
# 2. Runs PyInstaller with the .spec file
# 3. Verifies output structure
# 4. Runs smoke test on bundled executable
#
# Usage:
#   ./scripts/build_python_backend.sh [--skip-test]
#
# Options:
#   --skip-test    Skip the smoke test after building
#
# Requirements:
#   - Python 3.11+
#   - All dependencies from requirements.txt installed
#   - MLX framework (for Apple Silicon)
#   - mlx-audio-plus for Chatterbox TTS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Output directories
DIST_DIR="${PROJECT_ROOT}/dist"
BUILD_DIR="${PROJECT_ROOT}/build"
SPEC_FILE="${PROJECT_ROOT}/TalkyMcTalkface.spec"
OUTPUT_DIR="${DIST_DIR}/TalkyMcTalkface"
EXECUTABLE="${OUTPUT_DIR}/TalkyMcTalkface"

# Server settings
SERVER_HOST="127.0.0.1"
SERVER_PORT="5111"
SERVER_URL="http://${SERVER_HOST}:${SERVER_PORT}"

# Parse arguments
SKIP_TEST=false
for arg in "$@"; do
    case $arg in
        --skip-test)
            SKIP_TEST=true
            shift
            ;;
    esac
done

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}TalkyMcTalkface Python Backend Build${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Change to project root
cd "${PROJECT_ROOT}"

# Activate virtual environment if it exists
if [[ -f "${PROJECT_ROOT}/.venv/bin/activate" ]]; then
    echo "Activating virtual environment..."
    source "${PROJECT_ROOT}/.venv/bin/activate"
elif [[ -f "${PROJECT_ROOT}/venv/bin/activate" ]]; then
    echo "Activating virtual environment..."
    source "${PROJECT_ROOT}/venv/bin/activate"
fi

# -------------------------------------------------------------------
# Step 1: Verify Python environment
# -------------------------------------------------------------------
echo -e "${YELLOW}Step 1: Verifying Python environment...${NC}"

PYTHON_VERSION=$(python3 --version 2>&1)
echo "Python version: ${PYTHON_VERSION}"

# Check Python version is 3.11+
if ! python3 -c "import sys; exit(0 if sys.version_info >= (3, 11) else 1)" 2>/dev/null; then
    echo -e "${RED}Error: Python 3.11+ is required${NC}"
    exit 1
fi

# Verify required packages
echo "Checking required packages..."
REQUIRED_PACKAGES=(
    "fastapi"
    "uvicorn"
    "mlx"
    "mlx_audio"
    "scipy"
)

for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if python3 -c "import ${pkg}" 2>/dev/null; then
        echo "  [OK] ${pkg}"
    else
        echo -e "${RED}  [MISSING] ${pkg}${NC}"
        echo -e "${RED}Error: Required package '${pkg}' is not installed${NC}"
        exit 1
    fi
done

# Check for MLX support on Apple Silicon
if [[ $(uname -m) == "arm64" ]]; then
    echo "Checking MLX support..."
    if python3 -c "import mlx.core; print('MLX available')" 2>/dev/null; then
        echo "  [OK] MLX framework available"
    else
        echo -e "${RED}  [ERROR] MLX not available - requires Apple Silicon${NC}"
        exit 1
    fi
else
    echo -e "${RED}Error: MLX requires Apple Silicon (arm64)${NC}"
    exit 1
fi

echo -e "${GREEN}Python environment verified.${NC}"
echo ""

# -------------------------------------------------------------------
# Step 2: Install/verify PyInstaller
# -------------------------------------------------------------------
echo -e "${YELLOW}Step 2: Checking PyInstaller...${NC}"

if ! command -v pyinstaller &> /dev/null; then
    if ! python3 -c "import PyInstaller" 2>/dev/null; then
        echo "Installing PyInstaller..."
        if command -v uv &> /dev/null; then
            uv pip install pyinstaller
        else
            pip3 install pyinstaller
        fi
    fi
fi

PYINSTALLER_VERSION=$(python3 -c "import PyInstaller; print(PyInstaller.__version__)" 2>/dev/null || echo "unknown")
echo "PyInstaller version: ${PYINSTALLER_VERSION}"
echo -e "${GREEN}PyInstaller ready.${NC}"
echo ""

# -------------------------------------------------------------------
# Step 3: Clean previous build
# -------------------------------------------------------------------
echo -e "${YELLOW}Step 3: Cleaning previous build...${NC}"

if [[ -d "${BUILD_DIR}" ]]; then
    echo "Removing ${BUILD_DIR}..."
    rm -rf "${BUILD_DIR}"
fi

if [[ -d "${OUTPUT_DIR}" ]]; then
    echo "Removing ${OUTPUT_DIR}..."
    rm -rf "${OUTPUT_DIR}"
fi

echo -e "${GREEN}Clean complete.${NC}"
echo ""

# -------------------------------------------------------------------
# Step 4: Run PyInstaller
# -------------------------------------------------------------------
echo -e "${YELLOW}Step 4: Running PyInstaller...${NC}"

if [[ ! -f "${SPEC_FILE}" ]]; then
    echo -e "${RED}Error: Spec file not found at ${SPEC_FILE}${NC}"
    exit 1
fi

echo "Building with spec file: ${SPEC_FILE}"
echo "This may take several minutes..."
echo ""

pyinstaller "${SPEC_FILE}" --noconfirm

echo -e "${GREEN}PyInstaller build complete.${NC}"
echo ""

# -------------------------------------------------------------------
# Step 5: Verify output structure
# -------------------------------------------------------------------
echo -e "${YELLOW}Step 5: Verifying output structure...${NC}"

ERRORS=0

# Check executable exists
if [[ -f "${EXECUTABLE}" ]]; then
    echo "  [OK] Executable: ${EXECUTABLE}"
else
    echo -e "${RED}  [MISSING] Executable: ${EXECUTABLE}${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check executable is actually executable
if [[ -x "${EXECUTABLE}" ]]; then
    echo "  [OK] Executable permissions"
else
    echo -e "${RED}  [ERROR] Executable not marked as executable${NC}"
    chmod +x "${EXECUTABLE}" 2>/dev/null && echo "       Fixed permissions" || ERRORS=$((ERRORS + 1))
fi

# PyInstaller 6.x puts data in _internal directory
INTERNAL_DIR="${OUTPUT_DIR}/_internal"

# Check prompts directory
if [[ -d "${INTERNAL_DIR}/prompts" ]]; then
    PROMPT_COUNT=$(find "${INTERNAL_DIR}/prompts" -name "*.wav" 2>/dev/null | wc -l | tr -d ' ')
    echo "  [OK] Prompts directory (${PROMPT_COUNT} voice files)"
elif [[ -d "${OUTPUT_DIR}/prompts" ]]; then
    PROMPT_COUNT=$(find "${OUTPUT_DIR}/prompts" -name "*.wav" 2>/dev/null | wc -l | tr -d ' ')
    echo "  [OK] Prompts directory (${PROMPT_COUNT} voice files)"
else
    echo -e "${YELLOW}  [WARNING] Prompts directory not found${NC}"
fi

# Check app static files
if [[ -d "${INTERNAL_DIR}/app/static" ]] || [[ -d "${OUTPUT_DIR}/app/static" ]]; then
    echo "  [OK] Static files directory"
else
    echo -e "${YELLOW}  [WARNING] Static files directory not found${NC}"
fi

# Check app templates
if [[ -d "${INTERNAL_DIR}/app/templates" ]] || [[ -d "${OUTPUT_DIR}/app/templates" ]]; then
    echo "  [OK] Templates directory"
else
    echo -e "${YELLOW}  [WARNING] Templates directory not found${NC}"
fi

# Report bundle size
if [[ -d "${OUTPUT_DIR}" ]]; then
    BUNDLE_SIZE=$(du -sh "${OUTPUT_DIR}" 2>/dev/null | cut -f1)
    echo ""
    echo "Bundle size: ${BUNDLE_SIZE}"
fi

if [[ ${ERRORS} -gt 0 ]]; then
    echo -e "${RED}Error: ${ERRORS} verification error(s) found${NC}"
    exit 1
fi

echo -e "${GREEN}Output structure verified.${NC}"
echo ""

# -------------------------------------------------------------------
# Step 6: Smoke test (optional)
# -------------------------------------------------------------------
if [[ "${SKIP_TEST}" == "true" ]]; then
    echo -e "${YELLOW}Step 6: Skipping smoke test (--skip-test)${NC}"
else
    echo -e "${YELLOW}Step 6: Running smoke test...${NC}"

    # Check if port is already in use
    if lsof -i :${SERVER_PORT} &>/dev/null; then
        echo -e "${YELLOW}Warning: Port ${SERVER_PORT} is already in use${NC}"
        echo "Skipping smoke test to avoid conflicts"
    else
        # Start server in background
        echo "Starting bundled server..."
        "${EXECUTABLE}" &
        SERVER_PID=$!

        # Wait for server to start (up to 60 seconds for model loading)
        echo "Waiting for server to start (this may take up to 60 seconds)..."
        TIMEOUT=60
        ELAPSED=0
        while [[ ${ELAPSED} -lt ${TIMEOUT} ]]; do
            if curl -s "${SERVER_URL}/health" &>/dev/null; then
                break
            fi
            sleep 2
            ELAPSED=$((ELAPSED + 2))
            echo -n "."
        done
        echo ""

        # Check if server is running
        if curl -s "${SERVER_URL}/health" &>/dev/null; then
            echo -e "${GREEN}  [OK] Server started successfully${NC}"

            # Test health endpoint
            HEALTH_RESPONSE=$(curl -s "${SERVER_URL}/health")
            if echo "${HEALTH_RESPONSE}" | grep -q '"status":"ok"'; then
                echo -e "${GREEN}  [OK] Health check passed${NC}"
            else
                echo -e "${RED}  [FAIL] Health check returned unexpected response${NC}"
                echo "Response: ${HEALTH_RESPONSE}"
            fi

            # Test voices endpoint
            VOICES_RESPONSE=$(curl -s "${SERVER_URL}/voices")
            if echo "${VOICES_RESPONSE}" | grep -q '\['; then
                echo -e "${GREEN}  [OK] Voices endpoint working${NC}"
            else
                echo -e "${YELLOW}  [WARNING] Voices endpoint returned unexpected response${NC}"
            fi

            echo -e "${GREEN}Smoke test passed!${NC}"
        else
            echo -e "${RED}  [FAIL] Server failed to start within ${TIMEOUT} seconds${NC}"
            ERRORS=$((ERRORS + 1))
        fi

        # Clean up - terminate server
        echo "Stopping server..."
        if [[ -n "${SERVER_PID}" ]] && kill -0 "${SERVER_PID}" 2>/dev/null; then
            kill -TERM "${SERVER_PID}" 2>/dev/null
            sleep 2
            kill -9 "${SERVER_PID}" 2>/dev/null || true
        fi
        echo "Server stopped."
    fi
fi

echo ""

# -------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Build Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Output directory: ${OUTPUT_DIR}"
echo "Executable: ${EXECUTABLE}"
echo ""
echo "Next steps for macOS app integration:"
echo "1. Copy ${OUTPUT_DIR}/ to:"
echo "   TalkyMcTalkface.app/Contents/Resources/python-backend/"
echo ""
echo "2. The Swift app should launch:"
echo "   Contents/Resources/python-backend/TalkyMcTalkface"
echo ""

exit 0
