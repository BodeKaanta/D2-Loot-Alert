#!/usr/bin/env bash
# Takes the App Store screenshots (#10) in an iOS simulator.
#
#   tool/screenshots.sh <simulator id> [output folder]      (run from app/)
#
# Use the iPhone 18 Pro Max simulator: its screen is exactly Apple's 6.9" size,
# 1320 x 2868. `xcrun simctl list devices` shows the ids.
#
# It runs integration_test/screenshots_test.dart, which walks through the app
# and prints SCREENSHOT:<name> on each screen; this script captures the
# simulator's screen at each of those lines.
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE="${1:?usage: tool/screenshots.sh <simulator id> [output folder]}"
OUT="${2:-build/screenshots}"
mkdir -p "$OUT"

xcrun simctl boot "$DEVICE" 2>/dev/null || true # already booted is fine
xcrun simctl bootstatus "$DEVICE" -b >/dev/null
# Apple's classic 9:41 with a full battery and signal.
xcrun simctl status_bar "$DEVICE" override --time 9:41 --batteryState charged --batteryLevel 100 \
  --dataNetwork wifi --wifiBars 3 --cellularMode active --cellularBars 4

flutter test integration_test/screenshots_test.dart -d "$DEVICE" 2>&1 | while IFS= read -r line; do
  echo "$line"
  if [[ "$line" == *SCREENSHOT:* ]]; then
    name="${line##*SCREENSHOT:}"
    sleep 1 # the test holds the screen still for 4 s after printing
    xcrun simctl io "$DEVICE" screenshot "$OUT/$name.png" >/dev/null
    echo "  captured $OUT/$name.png"
  fi
done
