#!/bin/bash
# ============================================================================
# Sinhala FM Input Method — Install / Uninstall Script
# ============================================================================
# Installs the built .app bundle to ~/Library/Input Methods/
#
# Usage:
#   ./Scripts/install.sh              # Install the input method
#   ./Scripts/install.sh --uninstall  # Remove the input method
# ============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
APP_NAME="SinhalaFMInput"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
INSTALL_DIR="$HOME/Library/Input Methods"
INSTALLED_APP="$INSTALL_DIR/$APP_NAME.app"

# ============================================================================
# Uninstall
# ============================================================================

uninstall() {
    echo ""
    echo -e "${YELLOW}Uninstalling Sinhala FM Input Method...${NC}"
    echo ""
    
    # Kill any running instances
    if pgrep -x "$APP_NAME" > /dev/null 2>&1; then
        echo -e "${BLUE}▶${NC} Stopping running instance..."
        killall "$APP_NAME" 2>/dev/null || true
        sleep 1
        echo -e "${GREEN}✓${NC} Process stopped"
    fi
    
    # Remove the app bundle
    if [ -d "$INSTALLED_APP" ]; then
        echo -e "${BLUE}▶${NC} Removing $INSTALLED_APP..."
        rm -rf "$INSTALLED_APP"
        echo -e "${GREEN}✓${NC} App bundle removed"
    else
        echo -e "${YELLOW}⚠${NC} App not found at $INSTALLED_APP"
    fi
    
    echo ""
    echo -e "${GREEN}Uninstall complete.${NC}"
    echo ""
    echo -e "${YELLOW}Note:${NC} You may need to:"
    echo "  1. Remove the input source from System Settings → Keyboard → Input Sources"
    echo "  2. Log out and back in for changes to take full effect"
    echo ""
    exit 0
}

# Parse arguments
for arg in "$@"; do
    case $arg in
        --uninstall) uninstall ;;
        --help)
            echo "Usage: $0 [--uninstall] [--help]"
            echo "  --uninstall  Remove the input method"
            echo "  --help       Show this help"
            exit 0
            ;;
    esac
done

# ============================================================================
# Install
# ============================================================================

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   Sinhala FM Input Method — Install              ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# Check that the build exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo -e "${RED}✗${NC} Build not found at: $APP_BUNDLE"
    echo ""
    echo "  Run the build script first:"
    echo "    ./Scripts/build.sh"
    echo ""
    exit 1
fi
echo -e "${GREEN}✓${NC} Build found: $APP_BUNDLE"

# Kill any running instances
if pgrep -x "$APP_NAME" > /dev/null 2>&1; then
    echo -e "${BLUE}▶${NC} Stopping running instance..."
    killall "$APP_NAME" 2>/dev/null || true
    sleep 1
    echo -e "${GREEN}✓${NC} Previous instance stopped"
fi

# Create Input Methods directory if it doesn't exist
if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${BLUE}▶${NC} Creating $INSTALL_DIR..."
    mkdir -p "$INSTALL_DIR"
fi

# Remove old installation if present
if [ -d "$INSTALLED_APP" ]; then
    echo -e "${BLUE}▶${NC} Removing previous installation..."
    rm -rf "$INSTALLED_APP"
fi

# Copy the new build
echo -e "${BLUE}▶${NC} Installing to $INSTALL_DIR..."
cp -R "$APP_BUNDLE" "$INSTALLED_APP"
echo -e "${GREEN}✓${NC} App bundle installed"

# Verify the installation
if [ -f "$INSTALLED_APP/Contents/MacOS/$APP_NAME" ]; then
    echo -e "${GREEN}✓${NC} Executable verified"
else
    echo -e "${RED}✗${NC} Executable not found in installed bundle!"
    exit 1
fi

if [ -f "$INSTALLED_APP/Contents/Info.plist" ]; then
    echo -e "${GREEN}✓${NC} Info.plist verified"
else
    echo -e "${RED}✗${NC} Info.plist not found in installed bundle!"
    exit 1
fi

# ============================================================================
# Post-Install Instructions
# ============================================================================

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   INSTALLATION SUCCESSFUL                        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}Installed to:${NC} $INSTALLED_APP"
echo ""
echo -e "  ${YELLOW}To enable the input method:${NC}"
echo ""
echo "  1. Open System Settings (System Preferences)"
echo "  2. Go to Keyboard → Input Sources"
echo "  3. Click the '+' button"
echo "  4. Search for 'Sinhala FM' or browse under 'Sinhala'"
echo "  5. Select 'Sinhala FM Input' and click 'Add'"
echo ""
echo -e "  ${YELLOW}To use:${NC}"
echo ""
echo "  1. Click the input method icon in the menu bar (top-right)"
echo "  2. Select 'Sinhala FM Input'"
echo "  3. Select your FM font (e.g., FM-Abhaya) in your application"
echo "  4. Start typing — reordering happens automatically!"
echo ""
echo -e "  ${YELLOW}Troubleshooting:${NC}"
echo ""
echo "  • If the input method doesn't appear, try logging out and back in"
echo "  • Check Console.app for logs starting with 'SinhalaFMInput:'"
echo "  • Ensure the font profile (fm_abhaya_map.json) matches your FM font"
echo ""
echo -e "  ${YELLOW}To customize character mappings:${NC}"
echo ""
echo "  Edit: $INSTALLED_APP/Contents/Resources/fm_abhaya_map.json"
echo "  Then restart the input method (kill and re-select it)"
echo ""
