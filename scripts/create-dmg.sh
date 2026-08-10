#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="TripleS"
PROJECT="$ROOT_DIR/TripleS.xcodeproj"
DERIVED_DATA="$ROOT_DIR/build/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Release/Soundrift.app"
DIST_DIR="$ROOT_DIR/dist"

mkdir -p "$DIST_DIR"

echo "Building Soundrift (Release)..."
XCODEBUILD_ARGS=(
  -project "$PROJECT"
  -scheme "$SCHEME"
  -configuration Release
  -destination "platform=macOS"
  -derivedDataPath "$DERIVED_DATA"
)

if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
  XCODEBUILD_ARGS+=(CODE_SIGN_IDENTITY="$SIGNING_IDENTITY")
else
  XCODEBUILD_ARGS+=(CODE_SIGNING_ALLOWED=NO)
fi

xcodebuild "${XCODEBUILD_ARGS[@]}" build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected app bundle not found at $APP_PATH" >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist")"
OUTPUT_DMG="$DIST_DIR/Soundrift-${VERSION}.${BUILD}.dmg"

CREATE_DMG_ARGS=(--overwrite)
if [[ -z "${SIGNING_IDENTITY:-}" ]]; then
  CREATE_DMG_ARGS+=(--no-code-sign)
fi

echo "Creating DMG..."
if command -v create-dmg >/dev/null 2>&1; then
  create-dmg "$APP_PATH" "$DIST_DIR" "${CREATE_DMG_ARGS[@]}"
else
  npx --yes create-dmg@8 "$APP_PATH" "$DIST_DIR" "${CREATE_DMG_ARGS[@]}"
fi

GENERATED_DMG="$(find "$DIST_DIR" -maxdepth 1 -name 'Soundrift*.dmg' -type f ! -name "Soundrift-${VERSION}.${BUILD}.dmg" -print -quit)"
if [[ -n "$GENERATED_DMG" && "$GENERATED_DMG" != "$OUTPUT_DMG" ]]; then
  mv "$GENERATED_DMG" "$OUTPUT_DMG"
fi

echo "Release DMG ready: $OUTPUT_DMG"
