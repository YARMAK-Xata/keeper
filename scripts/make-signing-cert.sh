#!/bin/zsh
# Creates a local code-signing identity so Keeper's signature stays the same across rebuilds.
#
# Why this exists: an ad-hoc signature makes the app's designated requirement its exact binary
# hash, so every rebuild looks like a different app to macOS and the Accessibility permission you
# granted silently stops applying — the switch stays on in System Settings and Keeper still says
# it has no access. Signing with a certificate makes the requirement "this bundle id, signed by
# this certificate", which survives rebuilds.
#
# Run once. Safe to run again; it does nothing if the identity already exists.
set -euo pipefail
NAME="Keeper Local Signing"

if security find-certificate -c "$NAME" >/dev/null 2>&1; then
  echo "Identity \"$NAME\" already in the login keychain. Nothing to do."
  exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

openssl req -x509 -newkey rsa:2048 -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -days 3650 -nodes \
  -subj "/CN=$NAME" \
  -addext "basicConstraints=critical,CA:false" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning" 2>/dev/null

# Legacy PKCS#12 algorithms: OpenSSL 3's defaults are unreadable by the Security framework.
openssl pkcs12 -export -out "$TMP/id.p12" -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -passout pass:keeper -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES -macalg sha1 2>/dev/null

# -A lets codesign use the key without a keychain prompt on every build.
security import "$TMP/id.p12" -k ~/Library/Keychains/login.keychain-db -P keeper -T /usr/bin/codesign -A

echo "Created \"$NAME\". scripts/build-app.sh will use it from now on."
echo "To remove it later: open Keychain Access, find \"$NAME\", delete it."
