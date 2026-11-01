#!/bin/bash
# Installs (or updates) the latest Keep Me In release into /Applications.
#
#   With GitHub CLI signed in:
#     bash install.sh
#   No tools needed:
#     curl -fsSL https://raw.githubusercontent.com/elnabalawy23-netizen/keep-me-in/main/install.sh | bash
set -euo pipefail

REPO="${KEEPMEIN_REPO:-elnabalawy23-netizen/keep-me-in}"
APP_NAME="Keep Me In"
DEST="/Applications/${APP_NAME}.app"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

echo "▸ downloading the latest release of ${REPO}"
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  gh release download -R "${REPO}" -p 'KeepMeIn-*.zip' -D "${TMP}"
else
  URL="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | grep -o 'https://[^"]*KeepMeIn-[^"]*\.zip' | head -1)"
  if [ -z "${URL}" ]; then
    echo "✗ Could not find a release asset. For a private repo install GitHub CLI (brew install gh), run 'gh auth login', then rerun." >&2
    exit 1
  fi
  curl -fL "${URL}" -o "${TMP}/KeepMeIn.zip"
fi
ZIP="$(ls "${TMP}"/*.zip | head -1)"

echo "▸ installing to ${DEST}"
pkill -x KeepMeIn 2>/dev/null || true
ditto -x -k "${ZIP}" "${TMP}/unzipped"
rm -rf "${DEST}"
ditto "${TMP}/unzipped/${APP_NAME}.app" "${DEST}"
# The app is signed with a local certificate, not an Apple Developer ID, so clear the quarantine flag
# that would otherwise make Gatekeeper refuse to open a downloaded copy.
xattr -dr com.apple.quarantine "${DEST}" 2>/dev/null || true
open "${DEST}"

echo "✓ Installed ${APP_NAME}."
echo "  First run on a new Mac: allow it under System Settings → Privacy & Security → Accessibility."
echo "  That is once per Mac; later updates installed with this script keep the permission."
