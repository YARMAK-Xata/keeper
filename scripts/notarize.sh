#!/bin/zsh
# Notarizes build/Keeper.app and the disk image beside it, and staples Apple's ticket to both.
#
# This is the only thing that stops macOS showing "Apple could not verify that Keeper is free of
# malware" on someone else's Mac. Nothing in the code, the packaging or the instructions can
# substitute for it: Gatekeeper asks Apple whether this exact build was submitted, and either it
# was or it was not. In macOS 15 and later there is not even a Control-click bypass any more —
# whoever you send it to has to go into System Settings and click Open Anyway.
#
# Run it after scripts/make-dmg.sh, or let make-dmg.sh call it for you.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/signing-identity.sh

APP=build/Keeper.app
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG=${1:-build/Keeper-$VERSION.dmg}

if [[ "$SIGNING_KIND" != "developer-id" ]]; then
  cat <<'MISSING'
Cannot notarize: there is no Developer ID Application certificate in this keychain.

Notarization is Apple asking to see the build before anyone else runs it, and they will only
look at one signed by a Developer ID. That certificate comes with the Apple Developer Program,
which is a paid yearly membership — there is no free route to it, and no way to remove the
warning without it.

Once you have joined:

  1. In Xcode, or on developer.apple.com under Certificates, create a
     "Developer ID Application" certificate and download it into this keychain.

  2. Make an app-specific password at appleid.apple.com (Sign-In and Security →
     App-Specific Passwords). Your normal Apple password will not work here.

  3. Store it once, so no script ever handles the password again:

       xcrun notarytool store-credentials "keeper-notary" \
         --apple-id "you@example.com" --team-id "YOURTEAMID" --password "abcd-efgh-ijkl-mnop"

  4. Run scripts/make-dmg.sh again. It will sign, notarize and staple without being asked.

MISSING
  exit 1
fi

if ! security find-generic-password -s "com.apple.gke.notary.tool" -a "$NOTARY_PROFILE" >/dev/null 2>&1; then
  echo "Cannot notarize: no stored credentials called \"$NOTARY_PROFILE\"."
  echo "Run: xcrun notarytool store-credentials \"$NOTARY_PROFILE\" --apple-id … --team-id … --password …"
  exit 1
fi

# The app goes first, in a zip, because a ticket stapled to the app survives being dragged out of
# the disk image onto a Mac that is offline. Stapling only the image would leave the copy in
# Applications relying on Apple being reachable at the moment it is first opened.
echo "Notarizing the app…"
rm -f build/Keeper-notarize.zip
ditto -c -k --keepParent "$APP" build/Keeper-notarize.zip
xcrun notarytool submit build/Keeper-notarize.zip --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
rm -f build/Keeper-notarize.zip

# The image is signed and notarized in its own right, so the download itself is trusted and not
# just the thing inside it.
echo "Notarizing $DMG…"
codesign --force --sign "$IDENTITY" "${TIMESTAMP_FLAG[@]}" "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"

echo
echo "=== what a stranger's Mac will decide ==="
spctl -a -vv "$APP" 2>&1 | sed 's/^/  /'
spctl -a -t open --context context:primary-signature -vv "$DMG" 2>&1 | sed 's/^/  /'
xcrun stapler validate "$DMG" 2>&1 | tail -1 | sed 's/^/  /'
echo
echo "Notarized. $DMG opens on any Mac with no warning at all."
echo "The \"first time you open it\" section of docs/Open-me-first.txt is now wrong — delete it."
