#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$("$ROOT_DIR/Scripts/package-macos-companion.sh")"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"

fail() {
  echo "Verification failed: $1" >&2
  exit 1
}

[[ -d "$APP_BUNDLE" ]] || fail "missing app bundle at $APP_BUNDLE"
[[ "$(basename "$APP_BUNDLE")" == "Tinkerble.app" ]] || fail "app bundle is $(basename "$APP_BUNDLE"), expected Tinkerble.app"
[[ -x "$APP_BUNDLE/Contents/MacOS/TinkerbleCompanion" ]] || fail "missing executable"
[[ -f "$RESOURCES_DIR/Assets.car" ]] || fail "missing compiled Icon Composer Assets.car"
[[ -d "$RESOURCES_DIR/Tinkerble_TinkerbleCompanion.bundle" ]] || fail "missing companion resource bundle"
[[ -d "$RESOURCES_DIR/Tinkerble_TinkerbleCompanionUI.bundle" ]] || fail "missing companion UI resource bundle"
[[ -f "$RESOURCES_DIR/Tinkerble_TinkerbleCompanion.bundle/Contents/Resources/wings.pdf" ]] || fail "missing companion wings.pdf resource"
[[ -f "$RESOURCES_DIR/Tinkerble_TinkerbleCompanionUI.bundle/Contents/Resources/wings.pdf" ]] || fail "missing companion UI wings.pdf resource"

if find "$RESOURCES_DIR" -name "*.icns" -print -quit | grep -q .; then
  find "$RESOURCES_DIR" -name "*.icns" -print >&2
  fail "unexpected legacy .icns in companion resources"
fi

ICON_NAME="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconName" "$INFO_PLIST")"
[[ "$ICON_NAME" == "Tinkerble" ]] || fail "CFBundleIconName is $ICON_NAME, expected Tinkerble"

DISPLAY_NAME="$(/usr/libexec/PlistBuddy -c "Print :CFBundleDisplayName" "$INFO_PLIST")"
[[ "$DISPLAY_NAME" == "Tinkerble" ]] || fail "CFBundleDisplayName is $DISPLAY_NAME, expected Tinkerble"

BUNDLE_NAME="$(/usr/libexec/PlistBuddy -c "Print :CFBundleName" "$INFO_PLIST")"
[[ "$BUNDLE_NAME" == "Tinkerble" ]] || fail "CFBundleName is $BUNDLE_NAME, expected Tinkerble"

if /usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" "$INFO_PLIST" >/dev/null 2>&1; then
  fail "CFBundleIconFile should not be present for the macOS 26 Icon Composer path"
fi

MINIMUM_SYSTEM_VERSION="$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$INFO_PLIST")"
[[ "$MINIMUM_SYSTEM_VERSION" == "26.0" ]] || fail "LSMinimumSystemVersion is $MINIMUM_SYSTEM_VERSION, expected 26.0"

ASSET_INFO="$(mktemp)"
assetutil -I "$RESOURCES_DIR/Assets.car" > "$ASSET_INFO"
if ! grep -q '"Name" : "Tinkerble"' "$ASSET_INFO"; then
  rm -f "$ASSET_INFO"
  fail "compiled Assets.car does not contain the Tinkerble icon asset"
fi
rm -f "$ASSET_INFO"

codesign --verify "$APP_BUNDLE"

echo "Verified $APP_BUNDLE"
