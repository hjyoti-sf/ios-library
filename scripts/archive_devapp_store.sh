#!/bin/bash

# Release archive + App Store export + optional App Store validation (altool).
# Intended for CI; requires App Store Connect API key for automatic provisioning.
#
# Usage: archive_devapp_store.sh <derived_data_path> <output_root>
#
# Environment (required for signing + provisioning):
#   ASC_API_KEY_ID           App Store Connect API key ID
#   ASC_ISSUER_ID            App Store Connect issuer ID
#   ASC_API_KEY_P8_BASE64    Base64-encoded contents of the AuthKey_*.p8 file
#
# Optional:
#   SKIP_VALIDATE=1          Skip xcrun altool --validate-app (archive + export still run)

set -o pipefail
set -eu

ROOT_PATH="$(cd "$(dirname "${0}")/.." && pwd)"
DERIVED_DATA="${1:?derived data path required}"
OUT_ROOT="${2:?output root required}"
ARCHIVE_PATH="${OUT_ROOT}/DevApp.xcarchive"
EXPORT_DIR="${OUT_ROOT}/export"
EXPORT_PLIST="${ROOT_PATH}/scripts/export_options/DevApp_AppStore.plist"

if [[ -z "${ASC_API_KEY_ID:-}" || -z "${ASC_ISSUER_ID:-}" || -z "${ASC_API_KEY_P8_BASE64:-}" ]]; then
  echo "error: Set ASC_API_KEY_ID, ASC_ISSUER_ID, and ASC_API_KEY_P8_BASE64 (App Store Connect API key)." >&2
  exit 1
fi

KEY_DIR="${TMPDIR:-/tmp}/devapp_asc_keys_$$"
mkdir -p "$KEY_DIR"
KEY_PATH="${KEY_DIR}/AuthKey_${ASC_API_KEY_ID}.p8"
trap 'rm -rf "$KEY_DIR"' EXIT

echo -n "$ASC_API_KEY_P8_BASE64" | base64 --decode > "$KEY_PATH"
chmod 600 "$KEY_PATH"

cp -np "${ROOT_PATH}/DevApp/AirshipConfig.plist.sample" "${ROOT_PATH}/DevApp/AirshipConfig.plist" || true

echo -ne "\n\n *********** ARCHIVING DevApp (Release / iOS) *********** \n\n"

AUTH=(
  -authenticationKeyPath "$KEY_PATH"
  -authenticationKeyID "$ASC_API_KEY_ID"
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"
  -allowProvisioningUpdates
)

xcrun xcodebuild archive \
  -workspace "${ROOT_PATH}/Airship.xcworkspace" \
  -scheme DevApp \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  -derivedDataPath "$DERIVED_DATA" \
  "${AUTH[@]}" \
  | xcbeautify --renderer "${XCBEAUTIFY_RENDERER:-github-actions}"

rm -rf "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"

echo -ne "\n\n *********** EXPORTING DevApp IPA (app-store) *********** \n\n"

xcrun xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_PLIST" \
  "${AUTH[@]}" \
  | xcbeautify --renderer "${XCBEAUTIFY_RENDERER:-github-actions}"

IPA="$(find "$EXPORT_DIR" -maxdepth 3 -name '*.ipa' -print -quit)"
if [[ -z "$IPA" || ! -f "$IPA" ]]; then
  echo "error: No .ipa produced under $EXPORT_DIR" >&2
  exit 1
fi

echo "Exported: $IPA"

if [[ "${SKIP_VALIDATE:-0}" == "1" ]]; then
  echo "SKIP_VALIDATE=1 — skipping App Store validation."
  exit 0
fi

echo -ne "\n\n *********** VALIDATING IPA (altool) *********** \n\n"

xcrun altool --validate-app \
  --file "$IPA" \
  -t ios \
  --api-key "$ASC_API_KEY_ID" \
  --api-issuer "$ASC_ISSUER_ID" \
  --p8-file-path "$KEY_PATH"

echo "Validation succeeded."
