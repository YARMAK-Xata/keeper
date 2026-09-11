#!/bin/zsh
# Packages build/Keeper.app into a disk image you can send to someone who has never
# installed an app outside the App Store: drag the knight onto Applications, done.
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/build-app.sh

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" build/Keeper.app/Contents/Info.plist)
VOLUME="Keeper"
STAGE="build/dmg"
DMG="build/Keeper-$VERSION.dmg"

# A leftover mount from an interrupted run would collide with the volume name.
hdiutil detach "/Volumes/$VOLUME" -quiet 2>/dev/null || true
rm -rf "$STAGE" "$DMG" build/rw.dmg
mkdir -p "$STAGE"

cp -R build/Keeper.app "$STAGE/Keeper.app"
ln -s /Applications "$STAGE/Applications"
cp docs/Open-me-first.txt "$STAGE/Open me first.txt"
cp Assets/AppIcon.icns "$STAGE/.VolumeIcon.icns"

hdiutil create -volname "$VOLUME" -srcfolder "$STAGE" -ov -format UDRW -fs HFS+ build/rw.dmg >/dev/null
MOUNT=$(hdiutil attach build/rw.dmg -nobrowse -noautoopen | tail -1 | cut -f3-)

# The window layout is a nicety; a failure here must not cost us the disk image.
[[ -x /usr/bin/SetFile ]] && /usr/bin/SetFile -a C "$MOUNT" 2>/dev/null || true
osascript <<APPLESCRIPT >/dev/null 2>&1 || echo "  (could not set the window layout; the image is still fine)"
tell application "Finder"
  tell disk "$VOLUME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {240, 140, 780, 520}
    set options to the icon view options of container window
    set arrangement of options to not arranged
    set icon size of options to 96
    set text size of options to 12
    set position of item "Keeper.app" of container window to {140, 150}
    set position of item "Applications" of container window to {400, 150}
    set position of item "Open me first.txt" of container window to {270, 285}
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$MOUNT" -quiet
hdiutil convert build/rw.dmg -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -rf build/rw.dmg "$STAGE"

echo "Built $DMG ($(du -h "$DMG" | cut -f1))"
echo "Send that one file. Whoever opens it drags Keeper onto Applications."
