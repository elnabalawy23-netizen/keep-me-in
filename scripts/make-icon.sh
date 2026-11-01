#!/bin/bash
# Renders Packaging/make-icon.swift into build/AppIcon.icns
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
rm -rf build/AppIcon.iconset
swift Packaging/make-icon.swift build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
echo "Icon ready: build/AppIcon.icns"
