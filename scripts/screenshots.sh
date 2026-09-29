#!/bin/bash
# Builds the app, runs it in the iOS Simulator and captures screenshots and a short gameplay video
# into docs/screenshots. Needs macOS with Xcode.
set -euo pipefail
OUT=docs/screenshots
BUNDLE=com.example.soett
mkdir -p "$OUT"

UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
runtimes = sorted((r for r in devices if "iOS" in r), reverse=True)
for r in runtimes:
    for d in devices[r]:
        if d["name"].startswith("iPhone") and "Pro" in d["name"] and "Max" not in d["name"]:
            print(d["udid"]); sys.exit()
')
echo "Simulator: $UDID"

xcodebuild build -project Soett.xcodeproj -scheme Soett \
  -destination "id=$UDID" -derivedDataPath build CODE_SIGNING_ALLOWED=NO -quiet

xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl ui "$UDID" appearance light
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 \
  --wifiBars 3 --cellularBars 4 || true
xcrun simctl install "$UDID" build/Build/Products/Debug-iphonesimulator/Soett.app

run() { xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true; xcrun simctl launch "$UDID" "$BUNDLE" -sound NO -voice NO "$@"; }
shot() { xcrun simctl io "$UDID" screenshot "$OUT/$1.png"; }

run; sleep 5; shot 1-levels
run -demoLevel 3 -demoSeed 7; sleep 5; shot 2-jelly
run -demoLevel 7 -demoSeed 3; sleep 5; shot 3-chocolate

xcrun simctl io "$UDID" recordVideo --codec h264 --force build/gameplay.mp4 &
REC=$!
sleep 2
run -demoLevel 6 -demoSeed 11 -autoplay YES
sleep 4; shot 4-play
sleep 3
kill -INT $REC; wait $REC || true

xcrun simctl ui "$UDID" appearance dark
run -demoLevel 12 -demoSeed 5; sleep 5; shot 5-dark
ls -la "$OUT"
