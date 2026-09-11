#!/bin/zsh
# Builds build/Keeper.app from the SwiftPM release binary.
set -euo pipefail
cd "$(dirname "$0")/.."
# Built from a neutral scratch path on purpose. SwiftPM bakes the build-time location of the
# resource bundle into the accessor behind `Bundle.module`, as a fallback for when the bundle is
# not found beside the executable — so a release built in place ships a string naming whoever
# built it and the directory they keep their work in. Inside the .app the bundle is always
# adjacent, so the fallback is never used; this only decides what the string says.
SCRATCH=${KEEPER_SCRATCH:-/tmp/keeper-build}
swift build -c release --scratch-path "$SCRATCH" 2>&1 | tail -1
RELEASE="$SCRATCH/release"
APP=build/Keeper.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$RELEASE/Keeper" "$APP/Contents/MacOS/Keeper"
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# The strings tables travel twice on purpose: the SwiftPM resource bundle is what the app's own
# lookups read, and the .lproj folders in Contents/Resources are what makes macOS treat the
# bundle as localized, so AppKit's own menu items follow the same language.
cp -R "$RELEASE/Keeper_Keeper.bundle" "$APP/Contents/Resources/"
cp -R Sources/Keeper/Resources/*.lproj "$APP/Contents/Resources/"

# The layered icon for macOS 26, compiled from Assets/AppIcon.icon into an Assets.car that
# carries the Default, Dark, Clear and Tinted appearances. actool insists on absolute paths and
# on an output directory that already exists. Without Xcode there is no actool, and the .icns
# alone still works — macOS 26 just masks it less kindly, so say so rather than failing.
ICON_NAME_KEY=""
if ICON_TOOL=$(xcrun --find actool 2>/dev/null) && [[ -d Assets/AppIcon.icon ]]; then
  ICON_BUILD=$(mktemp -d)
  if "$ICON_TOOL" "$PWD/Assets/AppIcon.icon" --compile "$ICON_BUILD" --app-icon AppIcon \
        --platform macosx --minimum-deployment-target 26.0 \
        --output-partial-info-plist "$ICON_BUILD/icon.plist" >/dev/null 2>&1 \
     && [[ -f "$ICON_BUILD/Assets.car" ]]; then
    cp "$ICON_BUILD/Assets.car" "$APP/Contents/Resources/Assets.car"
    ICON_NAME_KEY="  <key>CFBundleIconName</key><string>AppIcon</string>"
  else
    echo "  (actool could not compile Assets/AppIcon.icon; using the .icns alone)"
  fi
  rm -rf "$ICON_BUILD"
else
  echo "  (no actool here; macOS 26 will fall back to the legacy .icns)"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Keeper</string>
  <key>CFBundleDisplayName</key><string>Keeper</string>
  <key>CFBundleIdentifier</key><string>dev.keeper.Keeper</string>
  <key>CFBundleVersion</key><string>11</string>
  <key>CFBundleShortVersionString</key><string>1.10</string>
  <key>CFBundleExecutable</key><string>Keeper</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
$ICON_NAME_KEY
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key>
  <array><string>en</string><string>uk</string><string>ru</string><string>de</string><string>fr</string><string>it</string><string>pl</string></array>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>Knight sprite by rgsdev, CC BY-SA 4.0</string>
</dict>
</plist>
PLIST
# Signing identity, best first. An ad-hoc signature ties the app's designated requirement to the
# exact binary hash, so every rebuild invalidates the Accessibility permission you granted while
# leaving the switch on in System Settings. A certificate makes the requirement survive rebuilds.
#
# The hardened runtime is on because this app holds Accessibility access: it stops other code
# being injected into a process that can read every browser window and press keys in it. It is
# also what notarization requires, and notarization is the only thing that stops macOS telling
# whoever you send this to that Apple could not check it for malware.
source "$(dirname "$0")/signing-identity.sh"

codesign --force --sign "$IDENTITY" --identifier dev.keeper.Keeper --options runtime \
  "${TIMESTAMP_FLAG[@]}" "$APP"
echo "Built $APP (signed with: $IDENTITY)"

case "$SIGNING_KIND" in
  adhoc)
    echo "  Ad-hoc signed: macOS will ask for Accessibility access again after every rebuild."
    echo "  Run scripts/make-signing-cert.sh once to stop that."
    ;;
  local|development)
    echo "  This signature works on this Mac. On anyone else's, macOS will refuse to open Keeper"
    echo "  and say Apple could not verify it is free of malware — only notarization removes that,"
    echo "  and only a Developer ID certificate can be notarized. See scripts/notarize.sh."
    ;;
esac
