#!/bin/bash
# Builds the Swift package and wraps it into build/Keep Me In.app (ad-hoc signed).
# Usage: scripts/build-app.sh [debug|release]
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP_NAME="Keep Me In"
EXECUTABLE="KeepMeIn"
BUNDLE_ID="com.omarelnabalawy.KeepMeIn"
APP="build/${APP_NAME}.app"

echo "▸ swift build -c ${CONFIG}"
swift build -c "${CONFIG}" --product "${EXECUTABLE}"
BIN="$(swift build -c "${CONFIG}" --show-bin-path)/${EXECUTABLE}"

[ -f build/AppIcon.icns ] || scripts/make-icon.sh

echo "▸ assembling ${APP}"
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"
cp "${BIN}" "${APP}/Contents/MacOS/${EXECUTABLE}"
cp Packaging/Info.plist "${APP}/Contents/Info.plist"
cp build/AppIcon.icns "${APP}/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "${APP}/Contents/PkgInfo"

# Signing identity, in order of preference. A stable identity is what keeps the Accessibility grant across updates.
# Override with IDENTITY="..." or create the local one with scripts/make-signing-cert.sh.
IDENTITIES="$(security find-identity -v -p codesigning 2>/dev/null || true)"
if [ -z "${IDENTITY:-}" ]; then
  for PATTERN in "Developer ID Application" "Apple Development" "${KEEPMEIN_SIGNING_IDENTITY:-Keep Me In Signing}"; do
    IDENTITY="$(printf '%s\n' "${IDENTITIES}" | awk -F'"' -v p="${PATTERN}" '$2 ~ p {print $2; exit}')"
    [ -n "${IDENTITY}" ] && break
  done
fi

if [ -n "${IDENTITY:-}" ]; then
  echo "▸ codesign with \"${IDENTITY}\""
  EXTRA=""
  case "${IDENTITY}" in "Developer ID Application"*) EXTRA="--options runtime --timestamp" ;; esac
  # shellcheck disable=SC2086  # EXTRA is intentionally word-split
  codesign --force --sign "${IDENTITY}" --identifier "${BUNDLE_ID}" ${EXTRA} "${APP}"
else
  echo "▸ codesign ad-hoc (no identity found; run scripts/make-signing-cert.sh so updates keep their permissions)"
  codesign --force --sign - --identifier "${BUNDLE_ID}" "${APP}"
fi

codesign --verify --strict "${APP}"
echo "  requirement: $(codesign -d -r- "${APP}" 2>&1 | sed -n 's/^designated => //p')"
echo "✓ ${APP}"
