#!/usr/bin/env bash
# Builds the latest Budbar, installs it to /Applications and launches it.
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/bundle.sh
osascript -e 'tell application "Budbar" to quit' >/dev/null 2>&1 || true
sleep 1
rm -rf /Applications/Budbar.app
cp -R build/Budbar.app /Applications/Budbar.app
open /Applications/Budbar.app
echo "Installed /Applications/Budbar.app"
