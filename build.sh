#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BUILD_DIR="$SCRIPT_DIR/build"
APP_DIR="$BUILD_DIR/FinderToys.app"
EXT_DIR="$APP_DIR/Contents/PlugIns/FinderToysExtension.appex"

echo "==> Preparing build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Extract base bundle resources
if [ -f "$SCRIPT_DIR/dist/MacNewFile.zip" ]; then
    unzip -q "$SCRIPT_DIR/dist/MacNewFile.zip" -d "$BUILD_DIR"
    if [ -d "$BUILD_DIR/MacNewFile.app" ]; then
        mv "$BUILD_DIR/MacNewFile.app" "$APP_DIR"
    fi
    if [ -d "$APP_DIR/Contents/PlugIns/MacNewFileFinderExtension.appex" ]; then
        mv "$APP_DIR/Contents/PlugIns/MacNewFileFinderExtension.appex" "$EXT_DIR"
    fi
elif [ -d "/Applications/FinderToys.app" ]; then
    cp -R "/Applications/FinderToys.app" "$APP_DIR"
elif [ -d "/Applications/MacNewFile.app" ]; then
    cp -R "/Applications/MacNewFile.app" "$APP_DIR"
    if [ -d "$APP_DIR/Contents/PlugIns/MacNewFileFinderExtension.appex" ]; then
        mv "$APP_DIR/Contents/PlugIns/MacNewFileFinderExtension.appex" "$EXT_DIR"
    fi
fi

# Clean old binaries
rm -f "$APP_DIR/Contents/MacOS/"*
rm -f "$EXT_DIR/Contents/MacOS/"*

echo "==> Compiling FinderToysExtension..."
mkdir -p "$EXT_DIR/Contents/MacOS"
clang -fobjc-arc \
  -framework Cocoa -framework FinderSync \
  -arch arm64 \
  -Wl,-e,_NSExtensionMain \
  "$SCRIPT_DIR/FinderToysExtension/FinderSync.m" \
  -o "$EXT_DIR/Contents/MacOS/FinderToysExtension"

echo "==> Compiling FinderToys (main app)..."
mkdir -p "$APP_DIR/Contents/MacOS"
clang -fobjc-arc \
  -framework Cocoa -framework ServiceManagement -framework ApplicationServices \
  -arch arm64 \
  "$SCRIPT_DIR/FinderToys/main.m" "$SCRIPT_DIR/FinderToys/AppDelegate.m" \
  -o "$APP_DIR/Contents/MacOS/FinderToys"

echo "==> Updating localization strings and assets..."
# Extension strings
mkdir -p "$EXT_DIR/Contents/Resources/ru.lproj"
cp "$SCRIPT_DIR/FinderToysExtension/ru.lproj/Localizable.strings" "$EXT_DIR/Contents/Resources/ru.lproj/"
mkdir -p "$EXT_DIR/Contents/Resources/en.lproj"
cp "$SCRIPT_DIR/FinderToysExtension/en.lproj/Localizable.strings" "$EXT_DIR/Contents/Resources/en.lproj/"
if [ -f "$SCRIPT_DIR/FinderToysExtension/it.lproj/Localizable.strings" ]; then
    mkdir -p "$EXT_DIR/Contents/Resources/it.lproj"
    cp "$SCRIPT_DIR/FinderToysExtension/it.lproj/Localizable.strings" "$EXT_DIR/Contents/Resources/it.lproj/"
fi

# Custom icons (JSON light and dark, plus toolbar add icons)
cp "$SCRIPT_DIR/FinderToysExtension/json.png" "$EXT_DIR/Contents/Resources/" 2>/dev/null || true
cp "$SCRIPT_DIR/FinderToysExtension/json-dark.png" "$EXT_DIR/Contents/Resources/" 2>/dev/null || true
cp "$SCRIPT_DIR/FinderToysExtension/Assets.xcassets/add.imageset/add.png" "$EXT_DIR/Contents/Resources/" 2>/dev/null || true
cp "$SCRIPT_DIR/FinderToysExtension/Assets.xcassets/add.imageset/add-dark.png" "$EXT_DIR/Contents/Resources/" 2>/dev/null || true

# Main app strings and icons
mkdir -p "$APP_DIR/Contents/Resources/ru.lproj"
cp "$SCRIPT_DIR/FinderToys/ru.lproj/Localizable.strings" "$APP_DIR/Contents/Resources/ru.lproj/"
mkdir -p "$APP_DIR/Contents/Resources/en.lproj"
cp "$SCRIPT_DIR/FinderToys/en.lproj/Localizable.strings" "$APP_DIR/Contents/Resources/en.lproj/"
if [ -f "$SCRIPT_DIR/FinderToys/it.lproj/Localizable.strings" ]; then
    mkdir -p "$APP_DIR/Contents/Resources/it.lproj"
    cp "$SCRIPT_DIR/FinderToys/it.lproj/Localizable.strings" "$APP_DIR/Contents/Resources/it.lproj/"
fi
cp "$SCRIPT_DIR/FinderToysExtension/Assets.xcassets/add.imageset/add.png" "$APP_DIR/Contents/Resources/add.png" 2>/dev/null || true
cp "$SCRIPT_DIR/FinderToysExtension/Assets.xcassets/add.imageset/add-dark.png" "$APP_DIR/Contents/Resources/add-dark.png" 2>/dev/null || true
if [ -f "$SCRIPT_DIR/FinderToys/AppIcon.icns" ]; then
    cp "$SCRIPT_DIR/FinderToys/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

# Configure App Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable FinderToys" "$APP_DIR/Contents/Info.plist" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string FinderToys" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName FinderToys" "$APP_DIR/Contents/Info.plist" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :CFBundleName string FinderToys" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName FinderToys" "$APP_DIR/Contents/Info.plist" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string FinderToys" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.danikk13.FinderToys" "$APP_DIR/Contents/Info.plist" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.danikk13.FinderToys" "$APP_DIR/Contents/Info.plist"

/usr/libexec/PlistBuddy -c "Delete :CFBundleLocalizations" "$APP_DIR/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleLocalizations array" "$APP_DIR/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleLocalizations:0 string ru" "$APP_DIR/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleLocalizations:1 string en" "$APP_DIR/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :NSAppleEventsUsageDescription" "$APP_DIR/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :NSAppleEventsUsageDescription string 'FinderToys needs to communicate with Finder to determine the active folder for file creation and paste operations.'" "$APP_DIR/Contents/Info.plist" 2>/dev/null || true

# Configure Extension Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable FinderToysExtension" "$EXT_DIR/Contents/Info.plist" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string FinderToysExtension" "$EXT_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName FinderToysExtension" "$EXT_DIR/Contents/Info.plist" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :CFBundleName string FinderToysExtension" "$EXT_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName 'FinderToys Extension'" "$EXT_DIR/Contents/Info.plist" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string 'FinderToys Extension'" "$EXT_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.danikk13.FinderToys.FinderToysExtension" "$EXT_DIR/Contents/Info.plist" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.danikk13.FinderToys.FinderToysExtension" "$EXT_DIR/Contents/Info.plist"

/usr/libexec/PlistBuddy -c "Delete :CFBundleLocalizations" "$EXT_DIR/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleLocalizations array" "$EXT_DIR/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleLocalizations:0 string ru" "$EXT_DIR/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleLocalizations:1 string en" "$EXT_DIR/Contents/Info.plist" 2>/dev/null || true

# Clean up any leftover debug dylibs
rm -f "$APP_DIR/Contents/MacOS/MacNewFile.debug.dylib" "$APP_DIR/Contents/MacOS/__preview.dylib" "$APP_DIR/Contents/Resources/MacNewFile.zip"

echo "==> Code-signing with entitlements..."
codesign --force --sign - --entitlements "$SCRIPT_DIR/FinderToysExtension/MacNewFileFinderExtension.entitlements" "$EXT_DIR/Contents/MacOS/FinderToysExtension"
codesign --force --sign - --entitlements "$SCRIPT_DIR/FinderToysExtension/MacNewFileFinderExtension.entitlements" "$EXT_DIR"
codesign --force --sign - -r="designated => identifier \"com.danikk13.FinderToys\"" --entitlements "$SCRIPT_DIR/FinderToys/MacNewFile.entitlements" "$APP_DIR/Contents/MacOS/FinderToys"
codesign --force --sign - -r="designated => identifier \"com.danikk13.FinderToys\"" --entitlements "$SCRIPT_DIR/FinderToys/MacNewFile.entitlements" "$APP_DIR"

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
    DMG_PATH="$SCRIPT_DIR/dist/FinderToys.dmg"
    rm -f "$DMG_PATH"

    hdiutil create -volname "FinderToys" \
      -srcfolder "$DMG_DIR" \
      -ov -format UDZO \
      "$DMG_PATH"

    rm -rf "$DMG_DIR"
    echo "==> DMG created successfully at: $DMG_PATH"
fi

if [ "$DO_INSTALL" = true ]; then
    echo "==> Installing to /Applications/FinderToys.app..."
    
    # Quit old instances (both MacNewFile and FinderToys)
    killall FinderToys 2>/dev/null || true
    killall FinderToysExtension 2>/dev/null || true
    killall MacNewFile 2>/dev/null || true
    killall MacNewFileFinderExtension 2>/dev/null || true
    sleep 1

    # Remove old MacNewFile and install FinderToys
    rm -rf "/Applications/MacNewFile.app"
    rm -rf "/Applications/FinderToys.app"
    cp -R "$APP_DIR" "/Applications/FinderToys.app"

    # Remove quarantine
    xattr -dr com.apple.quarantine "/Applications/FinderToys.app" 2>/dev/null || true

    # Permanent registration
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/FinderToys.app" 2>/dev/null || true
    pluginkit -a "/Applications/FinderToys.app/Contents/PlugIns/FinderToysExtension.appex" 2>/dev/null || true
    pluginkit -e use -i com.danikk13.FinderToys.FinderToysExtension 2>/dev/null || true

    # Clean up old toolbar identifiers and register FinderToys
    python3 -c "
import CoreFoundation as CF
app_id = 'com.apple.finder'
key = 'NSToolbar Configuration Browser'
val = CF.CFPreferencesCopyAppValue(key, app_id)
if val is not None:
    val = dict(val)
    items = list(val.get('TB Item Identifiers', []))
    items = [x for x in items if x not in ['com.haoqiqin.SuperRClick.FinderSync', 'net.langui.NewFileMenuFree.NewFileMenuFreeExtension', 'com.louieyin.MacNewFile.MacNewFileFinderExtension']]
    ft_item = 'com.danikk13.FinderToys.FinderToysExtension'
    if ft_item not in items:
        if 'com.apple.finder.SRCH' in items:
            idx = items.index('com.apple.finder.SRCH')
            items.insert(idx, ft_item)
        else:
            items.append(ft_item)
    val['TB Item Identifiers'] = items
    CF.CFPreferencesSetAppValue(key, val, app_id)
    CF.CFPreferencesAppSynchronize(app_id)
" 2>/dev/null || true

    # Restart Finder and launch
    killall Finder 2>/dev/null || true
    open "/Applications/FinderToys.app"
    echo "==> Installed and launched successfully!"
fi
