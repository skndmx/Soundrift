#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="TripleS"
PROJECT="$ROOT_DIR/TripleS.xcodeproj"
DERIVED_DATA="$ROOT_DIR/build/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Release/Soundrift.app"
DIST_DIR="$ROOT_DIR/dist"

mkdir -p "$DIST_DIR"
rm -f "$DIST_DIR"/*.dmg
rm -rf "$DERIVED_DATA"

echo "Building Soundrift (Release)..."
XCODEBUILD_ARGS=(
  -project "$PROJECT"
  -scheme "$SCHEME"
  -configuration Release
  -destination "platform=macOS"
  -derivedDataPath "$DERIVED_DATA"
  clean
  build
)

if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
  XCODEBUILD_ARGS+=(CODE_SIGN_IDENTITY="$SIGNING_IDENTITY")
else
  XCODEBUILD_ARGS+=(CODE_SIGNING_ALLOWED=NO)
fi

xcodebuild "${XCODEBUILD_ARGS[@]}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected app bundle not found at $APP_PATH" >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist")"
OUTPUT_DMG="$DIST_DIR/Soundrift-${VERSION}.${BUILD}.dmg"

CREATE_DMG_ARGS=(--overwrite --no-version-in-filename)
if [[ -z "${SIGNING_IDENTITY:-}" ]]; then
  CREATE_DMG_ARGS+=(--no-code-sign)
fi

echo "Creating DMG for Soundrift ${VERSION} (${BUILD})..."
if command -v create-dmg >/dev/null 2>&1; then
  create-dmg "$APP_PATH" "$DIST_DIR" "${CREATE_DMG_ARGS[@]}"
else
  npx --yes create-dmg@8 "$APP_PATH" "$DIST_DIR" "${CREATE_DMG_ARGS[@]}"
fi

GENERATED_DMG="$(find "$DIST_DIR" -maxdepth 1 -name '*.dmg' -type f ! -name "$(basename "$OUTPUT_DMG")" -print -quit)"
if [[ -n "$GENERATED_DMG" ]]; then
  mv "$GENERATED_DMG" "$OUTPUT_DMG"
elif [[ ! -f "$OUTPUT_DMG" ]]; then
  GENERATED_DMG="$(find "$DIST_DIR" -maxdepth 1 -name '*.dmg' -type f -print -quit)"
  if [[ -n "$GENERATED_DMG" && "$GENERATED_DMG" != "$OUTPUT_DMG" ]]; then
    mv "$GENERATED_DMG" "$OUTPUT_DMG"
  fi
fi

if [[ ! -f "$OUTPUT_DMG" ]]; then
  echo "DMG was not created at $OUTPUT_DMG" >&2
  exit 1
fi

MOUNT_POINT="$(hdiutil attach "$OUTPUT_DMG" -nobrowse -readonly | awk '/\/Volumes\// {print $3; exit}')"
BUILT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$MOUNT_POINT/Soundrift.app/Contents/Info.plist")"
BUILT_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$MOUNT_POINT/Soundrift.app/Contents/Info.plist")"
hdiutil detach "$MOUNT_POINT" >/dev/null

if [[ "$BUILT_VERSION" != "$VERSION" || "$BUILT_BUILD" != "$BUILD" ]]; then
  echo "DMG version mismatch: expected ${VERSION} (${BUILD}), got ${BUILT_VERSION} (${BUILT_BUILD})" >&2
  exit 1
fi

echo "Release DMG ready: $OUTPUT_DMG"
