#!/bin/bash
# Creates a local, self-signed code-signing identity ONCE. Every later build is signed with it, so macOS
# recognises updates as the same app and keeps the Accessibility grant, on this Mac and on any other Mac.
# Re-running is safe: it reuses the saved .p12 if the identity is missing from the keychain.
set -euo pipefail

NAME="${KEEPMEIN_SIGNING_IDENTITY:-Keep Me In Signing}"
DIR="${KEEPMEIN_SIGNING_DIR:-$HOME/.keepmein-signing}"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
OPENSSL=/usr/bin/openssl   # system LibreSSL writes PKCS#12 files that `security import` accepts

if security find-identity -v -p codesigning 2>/dev/null | grep -q "\"$NAME\""; then
  echo "✓ Signing identity '$NAME' already exists in your keychain."
  exit 0
fi

mkdir -p "$DIR"
chmod 700 "$DIR"

if [ -f "$DIR/signing.p12" ]; then
  echo "▸ reusing $DIR/signing.p12"
else
  echo "▸ generating certificate '$NAME' (valid 10 years)"
  cat > "$DIR/openssl.cnf" <<CNF
[ req ]
distinguished_name = dn
x509_extensions = codesign
prompt = no
[ dn ]
CN = $NAME
O = Keep Me In
[ codesign ]
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, keyCertSign
extendedKeyUsage = critical, codeSigning
subjectKeyIdentifier = hash
CNF
  "$OPENSSL" req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -keyout "$DIR/key.pem" -out "$DIR/cert.pem" -config "$DIR/openssl.cnf" 2>/dev/null
  PASS="$(uuidgen)"
  "$OPENSSL" pkcs12 -export -inkey "$DIR/key.pem" -in "$DIR/cert.pem" -name "$NAME" \
    -out "$DIR/signing.p12" -passout "pass:$PASS"
  printf '%s' "$PASS" > "$DIR/signing.p12.password"
  rm -f "$DIR/key.pem"
  chmod 600 "$DIR"/*
fi
PASS="$(cat "$DIR/signing.p12.password")"

echo "▸ importing into the login keychain"
security import "$DIR/signing.p12" -k "$KEYCHAIN" -P "$PASS" -T /usr/bin/codesign -T /usr/bin/security >/dev/null

echo "▸ trusting it for code signing (macOS asks for your login password once)"
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$DIR/cert.pem"

if security find-identity -v -p codesigning | grep -q "\"$NAME\""; then
  echo "✓ Identity ready: $NAME"
  echo "  Backup (private; needed only to sign from another Mac): $DIR/signing.p12 and signing.p12.password"
else
  echo "✗ Identity is not valid yet:" >&2
  security find-identity -p codesigning | grep "$NAME" >&2 || true
  exit 1
fi
