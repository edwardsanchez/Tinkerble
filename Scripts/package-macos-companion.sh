#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${TINKERBLE_COMPANION_APP_NAME:-Tinkerble}"
EXECUTABLE_NAME="TinkerbleCompanion"
BUNDLE_ID="${TINKERBLE_COMPANION_BUNDLE_ID:-app.amorfati.Tinkerble.Companion}"
VERSION="${TINKERBLE_COMPANION_VERSION:-0.1.0}"
BUILD_NUMBER="${TINKERBLE_COMPANION_BUILD:-1}"
CONFIGURATION="${CONFIGURATION:-debug}"
APP_BUNDLE="$ROOT_DIR/build/Tinkerble.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICON_SOURCE="${TINKERBLE_ICON_SOURCE:-$ROOT_DIR/Tinkerble.icon}"
ICON_ASSET_NAME="${TINKERBLE_ICON_ASSET_NAME:-$(basename "$ICON_SOURCE" .icon)}"
SIGN_IDENTITY="${TINKERBLE_SIGN_IDENTITY:--}"

swift_package() {
  env \
    -u SDKROOT \
    -u SDK_NAME \
    -u PLATFORM_NAME \
    -u EFFECTIVE_PLATFORM_NAME \
    -u SUPPORTED_PLATFORMS \
    -u SWIFT_PLATFORM_TARGET_PREFIX \
    -u SWIFT_TARGET_TRIPLE \
    -u ARCHS \
    -u VALID_ARCHS \
    swift "$@"
}

if [[ ! -d "$ICON_SOURCE" ]]; then
  echo "Missing icon document: $ICON_SOURCE" >&2
  exit 1
fi

ACTOOL="${ACTOOL:-$(xcrun -f actool)}"
if [[ ! -x "$ACTOOL" ]]; then
  echo "Could not find Xcode actool." >&2
  exit 1
fi

case "$CONFIGURATION" in
  Debug|debug)
    CONFIGURATION=debug
    ;;
  Release|release)
    CONFIGURATION=release
    ;;
  *)
    echo "CONFIGURATION must be 'debug' or 'release'." >&2
    exit 1
    ;;
esac

SWIFT_BUILD_FLAGS=(--package-path "$ROOT_DIR" --product "$EXECUTABLE_NAME")
if [[ "$CONFIGURATION" == "release" ]]; then
  SWIFT_BUILD_FLAGS+=(-c release)
fi

"$ROOT_DIR/Scripts/patch-rsocket-checkouts.sh" "$ROOT_DIR/.build/checkouts" >&2 || true
swift_package build "${SWIFT_BUILD_FLAGS[@]}" >&2
SHOW_BIN_PATH_FLAGS=(--package-path "$ROOT_DIR" --show-bin-path)
if [[ "$CONFIGURATION" == "release" ]]; then
  SHOW_BIN_PATH_FLAGS+=(-c release)
fi
BIN_PATH="$(swift_package build "${SHOW_BIN_PATH_FLAGS[@]}" 2>/dev/null)"
BUILT_EXECUTABLE="$BIN_PATH/$EXECUTABLE_NAME"

if [[ ! -x "$BUILT_EXECUTABLE" ]]; then
  echo "Built executable not found: $BUILT_EXECUTABLE" >&2
  exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BUILT_EXECUTABLE" "$MACOS_DIR/$EXECUTABLE_NAME"
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
PARTIAL_INFO_PLIST="$TMP_DIR/IconInfo.plist"

"$ACTOOL" "$ICON_SOURCE" \
  --compile "$RESOURCES_DIR" \
  --app-icon "$ICON_ASSET_NAME" \
  --platform macosx \
  --minimum-deployment-target 26.0 \
  --output-partial-info-plist "$PARTIAL_INFO_PLIST" \
  --standalone-icon-behavior none \
  --warnings \
  --errors \
  --output-format human-readable-text >&2

if [[ ! -f "$RESOURCES_DIR/Assets.car" ]]; then
  echo "Icon Composer asset did not compile into Assets.car." >&2
  exit 1
fi

# actool can still emit a legacy sidecar for external management tools. This app targets macOS 26,
# so keep the runtime icon path on the compiled Icon Composer asset only.
rm -f "$RESOURCES_DIR/$ICON_ASSET_NAME.icns" "$RESOURCES_DIR/AppIcon.icns"

cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleDisplayName</key>
	<string>$APP_NAME</string>
	<key>CFBundleExecutable</key>
	<string>$EXECUTABLE_NAME</string>
	<key>CFBundleIconName</key>
	<string>$ICON_ASSET_NAME</string>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$APP_NAME</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$VERSION</string>
	<key>CFBundleVersion</key>
	<string>$BUILD_NUMBER</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.developer-tools</string>
	<key>LSMinimumSystemVersion</key>
	<string>26.0</string>
	<key>NSBonjourServices</key>
	<array>
		<string>_tinkerble._tcp</string>
	</array>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSLocalNetworkUsageDescription</key>
	<string>Tinkerble listens for debug connections from local iOS development builds.</string>
</dict>
</plist>
EOF

codesign --force --sign "$SIGN_IDENTITY" "$APP_BUNDLE" >/dev/null

echo "$APP_BUNDLE"
