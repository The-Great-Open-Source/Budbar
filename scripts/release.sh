#!/usr/bin/env bash
# Builds a universal (Apple silicon + Intel) Budbar.app and zips it into dist/.
# Usage: scripts/release.sh [version]   (defaults to the latest git tag)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-$(git describe --tags --abbrev=0 2>/dev/null || echo 0.0.0)}"
VERSION="${VERSION#v}"

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Budbar"

APP="build/Budbar.app"
rm -rf "$APP" dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" dist
cp "$BIN" "$APP/Contents/MacOS/Budbar"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$VERSION" "$APP/Contents/Info.plist"

codesign --force --sign - "$APP"

ZIP="dist/Budbar-$VERSION.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
(cd dist && shasum -a 256 "Budbar-$VERSION.zip" > "Budbar-$VERSION.zip.sha256")
echo "Built $ZIP"
