#!/bin/bash
# ============================================================================
# Sinhala FM Input Method — Build Script
# ============================================================================
# Builds the macOS Input Method app bundle using swiftc.
#
# Usage:
#   ./Scripts/build.sh              # Build for current architecture
#   ./Scripts/build.sh --universal  # Build universal binary (arm64 + x86_64)
#   ./Scripts/build.sh --clean      # Clean and rebuild
#
# Prerequisites:
#   - Xcode Command Line Tools (xcode-select --install)
# ============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="SinhalaFMInput"
BUNDLE_ID="com.sinhala.inputmethod.fminput"
MODULE_NAME="SinhalaFMInput"
MIN_OS_VERSION="12.0"

# Paths (relative to project root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$PROJECT_DIR/Sources/$APP_NAME"
RES_DIR="$PROJECT_DIR/Resources"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

# Parse arguments
UNIVERSAL=false
CLEAN=false
for arg in "$@"; do
    case $arg in
        --universal) UNIVERSAL=true ;;
        --clean) CLEAN=true ;;
        --help)
            echo "Usage: $0 [--universal] [--clean] [--help]"
            echo "  --universal  Build for both arm64 and x86_64"
            echo "  --clean      Clean build directory before building"
            echo "  --help       Show this help"
            exit 0
            ;;
    esac
done

# ============================================================================
# Helper Functions
# ============================================================================

log_step() { echo -e "${BLUE}▶${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

# ============================================================================
# Pre-flight Checks
# ============================================================================

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   Sinhala FM Input Method — Build Script         ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

log_step "Checking prerequisites..."

# Check for swiftc
if ! command -v swiftc &> /dev/null; then
    log_error "swiftc not found! Install Xcode Command Line Tools:"
    echo "  xcode-select --install"
    exit 1
fi

SWIFT_VERSION=$(swiftc --version 2>&1 | head -1)
log_success "Swift compiler: $SWIFT_VERSION"

# Check for xcrun (needed for SDK path)
if ! command -v xcrun &> /dev/null; then
    log_error "xcrun not found! Install Xcode Command Line Tools:"
    echo "  xcode-select --install"
    exit 1
fi

SDK_PATH=$(xcrun --show-sdk-path 2>/dev/null || echo "")
if [ -z "$SDK_PATH" ]; then
    log_error "Could not find macOS SDK path!"
    exit 1
fi
log_success "SDK path: $SDK_PATH"

# Check source files exist
SWIFT_FILES=("$SRC_DIR"/*.swift)
if [ ${#SWIFT_FILES[@]} -eq 0 ]; then
    log_error "No Swift source files found in $SRC_DIR"
    exit 1
fi
log_success "Found ${#SWIFT_FILES[@]} source files"

# ============================================================================
# Clean
# ============================================================================

if [ "$CLEAN" = true ] || [ ! -d "$BUILD_DIR" ]; then
    log_step "Cleaning build directory..."
    rm -rf "$BUILD_DIR"
fi

# ============================================================================
# Create App Bundle Structure
# ============================================================================

log_step "Creating app bundle structure..."

mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

log_success "Bundle structure created"

# ============================================================================
# Compile
# ============================================================================

log_step "Compiling Swift sources..."

# Common compiler flags
COMMON_FLAGS=(
    -sdk "$SDK_PATH"
    -framework Cocoa
    -framework InputMethodKit
    -module-name "$MODULE_NAME"
    -O                           # Optimize for speed
    -whole-module-optimization   # Enable WMO
    -suppress-warnings           # Suppress non-critical warnings
)

if [ "$UNIVERSAL" = true ]; then
    log_step "Building universal binary (arm64 + x86_64)..."
    
    # Build for arm64
    log_step "  Compiling for arm64..."
    swiftc \
        -target arm64-apple-macos${MIN_OS_VERSION} \
        "${COMMON_FLAGS[@]}" \
        -o "$BUILD_DIR/${APP_NAME}_arm64" \
        "${SWIFT_FILES[@]}"
    
    # Build for x86_64
    log_step "  Compiling for x86_64..."
    swiftc \
        -target x86_64-apple-macos${MIN_OS_VERSION} \
        "${COMMON_FLAGS[@]}" \
        -o "$BUILD_DIR/${APP_NAME}_x86_64" \
        "${SWIFT_FILES[@]}"
    
    # Create universal binary with lipo
    log_step "  Creating universal binary..."
    lipo -create \
        "$BUILD_DIR/${APP_NAME}_arm64" \
        "$BUILD_DIR/${APP_NAME}_x86_64" \
        -output "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    
    # Clean up arch-specific binaries
    rm -f "$BUILD_DIR/${APP_NAME}_arm64" "$BUILD_DIR/${APP_NAME}_x86_64"
    
    log_success "Universal binary created"
else
    # Detect current architecture
    ARCH=$(uname -m)
    log_step "Building for $ARCH..."
    
    swiftc \
        -target ${ARCH}-apple-macos${MIN_OS_VERSION} \
        "${COMMON_FLAGS[@]}" \
        -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
        "${SWIFT_FILES[@]}"
    
    log_success "Binary compiled for $ARCH"
fi

# ============================================================================
# Copy Resources
# ============================================================================

log_step "Copying resources..."

# Copy Info.plist
cp "$RES_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
log_success "  Info.plist"

# Copy JSON mapping files
if [ -d "$SRC_DIR/Resources" ]; then
    for json_file in "$SRC_DIR/Resources"/*.json; do
        if [ -f "$json_file" ]; then
            cp "$json_file" "$APP_BUNDLE/Contents/Resources/"
            log_success "  $(basename "$json_file")"
        fi
    done
fi

# Copy entitlements (kept alongside for reference)
if [ -f "$RES_DIR/Entitlements.plist" ]; then
    cp "$RES_DIR/Entitlements.plist" "$APP_BUNDLE/Contents/Resources/Entitlements.plist"
    log_success "  Entitlements.plist"
fi

# ============================================================================
# Code Sign
# ============================================================================

log_step "Code signing..."

codesign --force --sign - \
    --entitlements "$RES_DIR/Entitlements.plist" \
    "$APP_BUNDLE"

log_success "Code signed (ad-hoc)"

# ============================================================================
# Summary
# ============================================================================

BINARY_SIZE=$(du -sh "$APP_BUNDLE/Contents/MacOS/$APP_NAME" | awk '{print $1}')
BUNDLE_SIZE=$(du -sh "$APP_BUNDLE" | awk '{print $1}')

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   BUILD SUCCESSFUL                                ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}App Bundle:${NC}  $APP_BUNDLE"
echo -e "  ${CYAN}Binary Size:${NC} $BINARY_SIZE"
echo -e "  ${CYAN}Bundle Size:${NC} $BUNDLE_SIZE"
echo ""
echo -e "  ${YELLOW}Next Steps:${NC}"
echo -e "  1. Install:  ${CYAN}./Scripts/install.sh${NC}"
echo -e "  2. Enable:   System Settings → Keyboard → Input Sources → + → Sinhala FM"
echo -e "  3. Switch:   Click the input method icon in the menu bar"
echo ""
