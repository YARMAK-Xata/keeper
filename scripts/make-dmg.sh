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

# The window's background carries the one instruction nobody can guess: what to do when macOS
# refuses to open Keeper the first time. A text file beside the icon was not enough — there is an
# app right there to double-click, and that is what people do.
mkdir -p "$STAGE/.background"
swift scripts/make-dmg-background.swift build/dmg-background >/dev/null
cp build/dmg-background.png "$STAGE/.background/background.png"
cp build/dmg-background@2x.png "$STAGE/.background/background@2x.png"
# One file carrying both resolutions, so the text is sharp on a retina display and right-sized on
# a Mac without one.
tiffutil -cathidpicheck build/dmg-background.png build/dmg-background@2x.png \
  -out "$STAGE/.background/background.tiff" >/dev/null 2>&1
rm -f "$STAGE/.background/background.png" "$STAGE/.background/background@2x.png"

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
    -- 28 points taller than the artwork, which is the title bar Finder puts above it.
    set the bounds of container window to {200, 90, 840, 708}
    set options to the icon view options of container window
    set arrangement of options to not arranged
    set icon size of options to 96
    set text size of options to 12
    set background picture of options to file ".background:background.tiff"
    -- These three match the artwork: the arrow is drawn between the first two, and the note sits
    -- under the line that points at it.
    set position of item "Keeper.app" of container window to {170, 112}
    set position of item "Applications" of container window to {470, 112}
    set position of item "Open me first.txt" of container window to {320, 487}
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

# With a Developer ID in the keychain the image is worth nothing until Apple has seen it, so go
# straight on and notarize. Without one, say plainly what the person receiving this will meet.
source scripts/signing-identity.sh
if [[ "$SIGNING_KIND" == "developer-id" ]]; then
  scripts/notarize.sh "$DMG"
else
  echo "Send that one file. Whoever opens it drags Keeper onto Applications."
  echo
  echo "  Not notarized. On another Mac this opens to \"Apple could not verify that Keeper is"
  echo "  free of malware\", offering only Move to Trash and Done — and since macOS 15 there is"
  echo "  no Control-click bypass, so they must go to System Settings → Privacy & Security and"
  echo "  click Open Anyway. docs/Open-me-first.txt walks through it in all seven languages."
  echo "  To remove the warning entirely, run scripts/notarize.sh to see what it needs."
fi
