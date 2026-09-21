#!/bin/bash
set -e

# ==============================================================================
#  FinderToys Installer Script
#  One-line installation:
#  curl -fsSL https://raw.githubusercontent.com/Danikk13/FinderToys/main/install.sh | bash
# ==============================================================================

echo ""
echo "  🛠️  Installing FinderToys for macOS..."
echo "  -------------------------------------------------"

# Check macOS
if [ "$(uname)" != "Darwin" ]; then
    echo "  ❌ Error: FinderToys only runs on macOS."
    exit 1
fi

REPO="Danikk13/FinderToys"
TMP_DIR=$(mktemp -d /tmp/findertoys.XXXXXX)
DMG_PATH="$TMP_DIR/FinderToys.dmg"

# Quit running instances
killall FinderToys 2>/dev/null || true
killall FinderToysExtension 2>/dev/null || true
killall MacNewFile 2>/dev/null || true
killall MacNewFileFinderExtension 2>/dev/null || true

# Try downloading from latest GitHub release first, fallback to raw repository
DOWNLOAD_URL="https://github.com/$REPO/releases/latest/download/FinderToys.dmg"
echo "  ⬇️  Downloading FinderToys.dmg..."

if ! curl -fsSL -o "$DMG_PATH" "$DOWNLOAD_URL" 2>/dev/null; then
    DOWNLOAD_URL="https://github.com/$REPO/releases/download/v2.0.0/FinderToys.dmg"
    if ! curl -fsSL -o "$DMG_PATH" "$DOWNLOAD_URL" 2>/dev/null; then
        echo "  ℹ️  Fetching from repository..."
        curl -fsSL -o "$DMG_PATH" "https://raw.githubusercontent.com/$REPO/main/dist/FinderToys.dmg" 2>/dev/null || true
    fi
fi

if [ ! -s "$DMG_PATH" ]; then
    echo "  ❌ Failed to download FinderToys.dmg. Please check https://github.com/$REPO/releases"
    rm -rf "$TMP_DIR"
    exit 1
fi

echo "  📦 Mounting disk image..."
MOUNT_POINT=$(hdiutil attach "$DMG_PATH" -nobrowse -readonly | grep -E "/Volumes" | awk -F'\t' '{print $NF}' | tr -d '\n')

if [ -z "$MOUNT_POINT" ] || [ ! -d "$MOUNT_POINT" ]; then
    echo "  ❌ Failed to mount DMG."
    rm -rf "$TMP_DIR"
    exit 1
fi

APP_SOURCE=$(find "$MOUNT_POINT" -maxdepth 1 -name "*.app" | head -n 1)
if [ -z "$APP_SOURCE" ]; then
    echo "  ❌ App bundle not found inside DMG."
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    rm -rf "$TMP_DIR"
    exit 1
fi

echo "  🚀 Installing to /Applications..."
rm -rf "/Applications/MacNewFile.app"
rm -rf "/Applications/FinderToys.app"
cp -R "$APP_SOURCE" "/Applications/FinderToys.app"

echo "  🧹 Cleaning up..."
hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
rm -rf "$TMP_DIR"

# Remove quarantine attribute
xattr -dr com.apple.quarantine "/Applications/FinderToys.app" 2>/dev/null || true

# Register Finder Extension permanently
echo "  🔌 Registering Finder extension..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/FinderToys.app" 2>/dev/null || true
pluginkit -a "/Applications/FinderToys.app/Contents/PlugIns/FinderToysExtension.appex" 2>/dev/null || true
pluginkit -e use -i com.danikk13.FinderToys.FinderToysExtension 2>/dev/null || true

# Launch App
open "/Applications/FinderToys.app"
killall Finder 2>/dev/null || true

echo ""
echo "  ✅ FinderToys successfully installed!"
echo "  -------------------------------------------------"
echo "  ⚡ Next steps:"
echo "  1. System Settings -> Privacy & Security -> Accessibility: Ensure FinderToys is enabled."
echo "  2. System Settings -> General -> Login Items & Extensions: Ensure FinderToys Extension is ON."
echo "  -------------------------------------------------"
echo "  🎉 Enjoy FinderToys! (Enter to open, F2 to rename, ⌘V to paste files)"
echo ""
