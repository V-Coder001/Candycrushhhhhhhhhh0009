#!/usr/bin/env bash
# Archives Sött and uploads it to App Store Connect / TestFlight.
#
# Signing is fully automatic through an App Store Connect API key, so no certificate
# or provisioning profile has to live in the repo. Needed environment:
#   ASC_KEY_ID, ASC_ISSUER_ID  key id and issuer id of the API key (role Admin)
#   ASC_KEY_P8                 contents of the downloaded AuthKey_XXXX.p8
#   APPLE_TEAM_ID              10-character team id from developer.apple.com
#   BUILD_NUMBER               CFBundleVersion, must grow with every upload
# Without the key the script only builds an unsigned archive to prove it compiles.
set -euo pipefail

cd "$(dirname "$0")/.."
OUT=build/testflight
ARCHIVE=$OUT/Soett.xcarchive
mkdir -p "$OUT"
xcodebuild -version

if [[ -z "${ASC_KEY_ID:-}" || -z "${ASC_ISSUER_ID:-}" || -z "${ASC_KEY_P8:-}" || -z "${APPLE_TEAM_ID:-}" ]]; then
  echo "::notice::App Store Connect key not configured, building an unsigned archive only (no upload)."
  xcodebuild archive \
    -project Soett.xcodeproj -scheme Soett -configuration Release \
    -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
    CURRENT_PROJECT_VERSION="${BUILD_NUMBER:-1}" CODE_SIGNING_ALLOWED=NO \
    > "$OUT/archive.log" 2>&1 || { tail -60 "$OUT/archive.log"; exit 1; }
  grep -E "ARCHIVE SUCCEEDED" "$OUT/archive.log"
  exit 0
fi

KEY="$RUNNER_TEMP/AuthKey_$ASC_KEY_ID.p8"
printf '%s\n' "$ASC_KEY_P8" > "$KEY"
AUTH=(-allowProvisioningUpdates
      -authenticationKeyPath "$KEY"
      -authenticationKeyID "$ASC_KEY_ID"
      -authenticationKeyIssuerID "$ASC_ISSUER_ID")

echo "Archiving build $BUILD_NUMBER for team $APPLE_TEAM_ID"
set +e
xcodebuild archive \
  -project Soett.xcodeproj -scheme Soett -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" CODE_SIGN_STYLE=Automatic \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  "${AUTH[@]}" > "$OUT/archive.log" 2>&1
status=$?
set -e
grep -E "error:|ARCHIVE (SUCCEEDED|FAILED)" "$OUT/archive.log" || true
[[ $status -eq 0 ]] || { tail -60 "$OUT/archive.log"; exit $status; }

cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>signingStyle</key><string>automatic</string>
  <key>teamID</key><string>$APPLE_TEAM_ID</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST

echo "Exporting and uploading to App Store Connect"
set +e
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" -exportPath "$OUT/export" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" \
  "${AUTH[@]}" > "$OUT/export.log" 2>&1
status=$?
set -e
grep -E "error:|EXPORT (SUCCEEDED|FAILED)|Upload succeeded|Uploaded" "$OUT/export.log" || true
[[ $status -eq 0 ]] || { tail -60 "$OUT/export.log"; exit $status; }
echo "::notice::Build $BUILD_NUMBER is uploaded. Apple processes it for a few minutes before it shows up in TestFlight."
