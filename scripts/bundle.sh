#!/usr/bin/env bash
# Builds Budbar and wraps it into build/Budbar.app (ad-hoc signed).
# Usage: scripts/bundle.sh [--open]
set -euo pipefail

cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Budbar"

APP="build/Budbar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Budbar"
cp Resources/Info.plist "$APP/Contents/Info.plist"

codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--open" ]]; then
    open "$APP"
fi
