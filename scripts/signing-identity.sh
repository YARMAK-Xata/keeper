# Sourced by the build and packaging scripts. Sets two variables:
#
#   IDENTITY      what to pass to `codesign --sign`
#   SIGNING_KIND  developer-id | development | local | adhoc
#
# The order is the order of how far the result travels. Only a Developer ID certificate can be
# notarized, and only a notarized app opens on someone else's Mac without them being told that
# Apple could not check it for malware. Everything below it works on this Mac and nowhere else.
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
  | awk -F'"' '/Developer ID Application/ {print $2; exit}' || true)
SIGNING_KIND=developer-id

if [[ -z "$IDENTITY" ]]; then
  IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
    | awk -F'"' '/Apple Development/ {print $2; exit}' || true)
  SIGNING_KIND=development
fi
if [[ -z "$IDENTITY" ]] && security find-certificate -c "Keeper Local Signing" >/dev/null 2>&1; then
  IDENTITY="Keeper Local Signing"
  SIGNING_KIND=local
fi
if [[ -z "$IDENTITY" ]]; then
  IDENTITY="-"
  SIGNING_KIND=adhoc
fi

# Notarization needs a secure timestamp from Apple's server. A local certificate cannot have one
# and does not need one, and asking for it only makes every build wait on the network.
if [[ "$SIGNING_KIND" == "developer-id" ]]; then
  TIMESTAMP_FLAG=(--timestamp)
else
  TIMESTAMP_FLAG=(--timestamp=none)
fi

# The keychain profile `xcrun notarytool store-credentials` wrote. Override with
# KEEPER_NOTARY_PROFILE if you called it something else.
NOTARY_PROFILE=${KEEPER_NOTARY_PROFILE:-keeper-notary}
