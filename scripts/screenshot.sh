#!/usr/bin/env bash
# Captures README screenshots using demo mode (no earbuds needed).
# Usage: scripts/screenshot.sh popover
# Click the Budbar menu bar icon, pick a mode, then click the popover when the cursor turns into a camera.
set -euo pipefail
cd "$(dirname "$0")/.."
name="${1:-popover}"
open build/Budbar.app --args --demo
echo "Open the Budbar popover, then click it to capture. Saving docs/screenshots/$name.png"
sleep 3
screencapture -o -w "docs/screenshots/$name.png"
