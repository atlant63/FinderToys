#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BUILD_DIR="$SCRIPT_DIR/build"
APP_DIR="$BUILD_DIR/MacNewFile.app"
EXT_DIR="$APP_DIR/Contents/PlugIns/MacNewFileFinderExtension.appex"

echo "==> Preparing build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Extract base bundle resources from dist/MacNewFile.zip
if [ -f "$SCRIPT_DIR/dist/MacNewFile.zip" ]; then
    unzip -q "$SCRIPT_DIR/dist/MacNewFile.zip" -d "$BUILD_DIR"
elif [ -d "/Applications/MacNewFile.app" ]; then
    cp -R "/Applications/MacNewFile.app" "$BUILD_DIR/"
else
    echo "Error: Neither dist/MacNewFile.zip nor /Applications/MacNewFile.app found for base resources."
    exit 1
fi

echo "==> Compiling MacNewFileFinderExtension..."
mkdir -p "$EXT_DIR/Contents/MacOS"
clang -fobjc-arc \
  -framework Cocoa -framework FinderSync \
  -arch arm64 \
  -Wl,-e,_NSExtensionMain \
  "$SCRIPT_DIR/MacNewFileFinderExtension/FinderSync.m" \
  -o "$EXT_DIR/Contents/MacOS/MacNewFileFinderExtension"

echo "==> Compiling MacNewFile (main app)..."
mkdir -p "$APP_DIR/Contents/MacOS"
clang -fobjc-arc \
  -framework Cocoa -framework ServiceManagement -framework ApplicationServices \
  -arch arm64 \
  "$SCRIPT_DIR/MacNewFile/main.m" "$SCRIPT_DIR/MacNewFile/AppDelegate.m" \
  -o "$APP_DIR/Contents/MacOS/MacNewFile"

echo "==> Updating localization strings..."
# Extension strings
mkdir -p "$EXT_DIR/Contents/Resources/ru.lproj"
cp "$SCRIPT_DIR/MacNewFileFinderExtension/ru.lproj/Localizable.strings" "$EXT_DIR/Contents/Resources/ru.lproj/"
mkdir -p "$EXT_DIR/Contents/Resources/en.lproj"
cp "$SCRIPT_DIR/MacNewFileFinderExtension/en.lproj/Localizable.strings" "$EXT_DIR/Contents/Resources/en.lproj/"
if [ -f "$SCRIPT_DIR/MacNewFileFinderExtension/it.lproj/Localizable.strings" ]; then
    mkdir -p "$EXT_DIR/Contents/Resources/it.lproj"
    cp "$SCRIPT_DIR/MacNewFileFinderExtension/it.lproj/Localizable.strings" "$EXT_DIR/Contents/Resources/it.lproj/"
fi

# Custom icons (JSON light and dark, plus toolbar add icons)
cp "$SCRIPT_DIR/MacNewFileFinderExtension/json.png" "$EXT_DIR/Contents/Resources/"
cp "$SCRIPT_DIR/MacNewFileFinderExtension/json-dark.png" "$EXT_DIR/Contents/Resources/"
cp "$SCRIPT_DIR/MacNewFileFinderExtension/Assets.xcassets/add.imageset/add.png" "$EXT_DIR/Contents/Resources/"
cp "$SCRIPT_DIR/MacNewFileFinderExtension/Assets.xcassets/add.imageset/add-dark.png" "$EXT_DIR/Contents/Resources/"

# Main app strings and icons
mkdir -p "$APP_DIR/Contents/Resources/ru.lproj"
cp "$SCRIPT_DIR/MacNewFile/ru.lproj/Localizable.strings" "$APP_DIR/Contents/Resources/ru.lproj/"
mkdir -p "$APP_DIR/Contents/Resources/en.lproj"
cp "$SCRIPT_DIR/MacNewFile/en.lproj/Localizable.strings" "$APP_DIR/Contents/Resources/en.lproj/"
if [ -f "$SCRIPT_DIR/MacNewFile/it.lproj/Localizable.strings" ]; then
    mkdir -p "$APP_DIR/Contents/Resources/it.lproj"
    cp "$SCRIPT_DIR/MacNewFile/it.lproj/Localizable.strings" "$APP_DIR/Contents/Resources/it.lproj/"
fi
cp "$SCRIPT_DIR/MacNewFileFinderExtension/Assets.xcassets/add.imageset/add.png" "$APP_DIR/Contents/Resources/add.png"
cp "$SCRIPT_DIR/MacNewFileFinderExtension/Assets.xcassets/add.imageset/add-dark.png" "$APP_DIR/Contents/Resources/add-dark.png"
if [ -f "$SCRIPT_DIR/MacNewFile/AppIcon.icns" ]; then
    cp "$SCRIPT_DIR/MacNewFile/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

# Configure supported localizations in Info.plist
/usr/libexec/PlistBuddy -c "Delete :CFBundleLocalizations" "$APP_DIR/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleLocalizations array" "$APP_DIR/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleLocalizations:0 string ru" "$APP_DIR/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleLocalizations:1 string en" "$APP_DIR/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :NSAppleEventsUsageDescription" "$APP_DIR/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :NSAppleEventsUsageDescription string 'FinderToys needs to communicate with Finder to determine the active folder for file creation and paste operations.'" "$APP_DIR/Contents/Info.plist" 2>/dev/null || true

/usr/libexec/PlistBuddy -c "Delete :CFBundleLocalizations" "$EXT_DIR/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleLocalizations array" "$EXT_DIR/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleLocalizations:0 string ru" "$EXT_DIR/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleLocalizations:1 string en" "$EXT_DIR/Contents/Info.plist" 2>/dev/null || true

# Clean up any leftover debug dylibs or zip archives
rm -f "$APP_DIR/Contents/MacOS/MacNewFile.debug.dylib" "$APP_DIR/Contents/MacOS/__preview.dylib" "$APP_DIR/Contents/Resources/MacNewFile.zip"

echo "==> Code-signing with entitlements..."
codesign --force --sign - --entitlements "$SCRIPT_DIR/MacNewFileFinderExtension/MacNewFileFinderExtension.entitlements" "$EXT_DIR/Contents/MacOS/MacNewFileFinderExtension"
codesign --force --sign - --entitlements "$SCRIPT_DIR/MacNewFileFinderExtension/MacNewFileFinderExtension.entitlements" "$EXT_DIR"
codesign --force --sign - -r="designated => identifier \"com.louieyin.MacNewFile\"" --entitlements "$SCRIPT_DIR/MacNewFile/MacNewFile.entitlements" "$APP_DIR/Contents/MacOS/MacNewFile"
codesign --force --sign - -r="designated => identifier \"com.louieyin.MacNewFile\"" --entitlements "$SCRIPT_DIR/MacNewFile/MacNewFile.entitlements" "$APP_DIR"

codesign --verify --deep "$APP_DIR"
echo "==> Build complete: $APP_DIR"

DO_INSTALL=false
DO_DMG=false

for arg in "$@"; do
    case "$arg" in
        --install|-i)
            DO_INSTALL=true
            ;;
        --dmg|-d)
            DO_DMG=true
            ;;
    esac
done

if [ "$DO_DMG" = true ]; then
    echo "==> Creating DMG installer..."
    DMG_DIR="$BUILD_DIR/dmg_staging"
    rm -rf "$DMG_DIR"
    mkdir -p "$DMG_DIR"
    cp -R "$APP_DIR" "$DMG_DIR/"
    ln -s /Applications "$DMG_DIR/Applications"

    mkdir -p "$SCRIPT_DIR/dist"
    DMG_PATH="$SCRIPT_DIR/dist/MacNewFile.dmg"
    rm -f "$DMG_PATH"

    hdiutil create -volname "MacNewFile" \
      -srcfolder "$DMG_DIR" \
      -ov -format UDZO \
      "$DMG_PATH"

    rm -rf "$DMG_DIR"
    echo "==> DMG created successfully at: $DMG_PATH"
fi

if [ "$DO_INSTALL" = true ]; then
    echo "==> Installing to /Applications/MacNewFile.app..."
    
    # Quit running instances
    killall MacNewFile 2>/dev/null || true
    killall MacNewFileFinderExtension 2>/dev/null || true
    sleep 1

    # Replace /Applications/MacNewFile.app
    rm -rf "/Applications/MacNewFile.app"
    cp -R "$APP_DIR" "/Applications/MacNewFile.app"

    # Remove quarantine
    xattr -dr com.apple.quarantine "/Applications/MacNewFile.app" 2>/dev/null || true

    # Re-register extension
    pluginkit -e use -i com.louieyin.MacNewFile.MacNewFileFinderExtension 2>/dev/null || true

    # Clean up stale/ghost Finder toolbar items and ensure MacNewFile toolbar item is registered
    python3 -c "
import CoreFoundation as CF
app_id = 'com.apple.finder'
key = 'NSToolbar Configuration Browser'
val = CF.CFPreferencesCopyAppValue(key, app_id)
if val is not None:
    val = dict(val)
    items = list(val.get('TB Item Identifiers', []))
    items = [x for x in items if x not in ['com.haoqiqin.SuperRClick.FinderSync', 'net.langui.NewFileMenuFree.NewFileMenuFreeExtension']]
    mac_new_file = 'com.louieyin.MacNewFile.MacNewFileFinderExtension'
    if mac_new_file not in items:
        if 'com.apple.finder.SRCH' in items:
            idx = items.index('com.apple.finder.SRCH')
            items.insert(idx, mac_new_file)
        else:
            items.append(mac_new_file)
    val['TB Item Identifiers'] = items
    CF.CFPreferencesSetAppValue(key, val, app_id)
    CF.CFPreferencesAppSynchronize(app_id)
" 2>/dev/null || true

    # Restart Finder
    killall Finder 2>/dev/null || true

    # Open app
    open "/Applications/MacNewFile.app"
    echo "==> Installed and launched successfully!"
fi
