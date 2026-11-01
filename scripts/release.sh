#!/bin/bash
# Builds, zips, and publishes a GitHub release for the version in Packaging/Info.plist.
# Usage: scripts/release.sh            (uses the repo this checkout is linked to)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Packaging/Info.plist)"
TAG="v${VERSION}"
APP="build/Keep Me In.app"
ZIP="build/KeepMeIn-${VERSION}.zip"
REPO="${KEEPMEIN_REPO:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"

scripts/build-app.sh release

if codesign -dv "${APP}" 2>&1 | grep -q "Signature=adhoc"; then
  echo "✗ Refusing to publish an ad-hoc signed build. Run 'make cert' first so updates keep their permissions." >&2
  exit 1
fi

rm -f "${ZIP}"
ditto -c -k --sequesterRsrc --keepParent "${APP}" "${ZIP}"
echo "▸ $(du -h "${ZIP}" | cut -f1) ${ZIP}"

if gh release view "${TAG}" -R "${REPO}" >/dev/null 2>&1; then
  gh release upload "${TAG}" "${ZIP}" -R "${REPO}" --clobber
else
  gh release create "${TAG}" "${ZIP}" -R "${REPO}" --title "Keep Me In ${VERSION}" --generate-notes
fi
echo "✓ Released ${TAG}: https://github.com/${REPO}/releases/tag/${TAG}"
