#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/Tinkerble Demo/Tinkerble Demo.xcodeproj"
SCHEME="Tinkerble Demo"
PACKAGE_CACHE="${TINKERBLE_DEMO_PACKAGE_CACHE:-$ROOT_DIR/.build-demo-run}"
APP_BUNDLE_ID="app.amorfati.Tinkerble-Demo"

choose_simulator() {
  if [[ -n "${TINKERBLE_SIMULATOR_UDID:-}" ]]; then
    echo "$TINKERBLE_SIMULATOR_UDID"
    return
  fi

  devices=()
  while IFS= read -r device; do
    devices+=("$device")
  done < <(xcrun simctl list devices available | awk -F '[()]' '/iPhone/ && /Shutdown|Booted/ {print $1 "|" $2}' | sed 's/[[:space:]]*$//')
  if [[ "${#devices[@]}" -eq 0 ]]; then
    echo "No available iPhone simulators found." >&2
    exit 1
  fi

  if [[ "${TINKERBLE_INTERACTIVE:-1}" == "0" ]]; then
    echo "${devices[0]#*|}"
    return
  fi

  echo "Available iPhone simulators:" >&2
  for index in "${!devices[@]}"; do
    echo "  $((index + 1)). ${devices[$index]%|*}" >&2
  done
  read -r -p "Choose a simulator number, or press Return for 1: " choice
  choice="${choice:-1}"
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#devices[@]} )); then
    echo "Canceled." >&2
    exit 1
  fi
  echo "${devices[$((choice - 1))]#*|}"
}

"$ROOT_DIR/Scripts/launch-macos-companion.sh"

SIMULATOR_UDID="$(choose_simulator)"
xcrun simctl boot "$SIMULATOR_UDID" 2>/dev/null || true

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
  -clonedSourcePackagesDirPath "$PACKAGE_CACHE" \
  -skipMacroValidation \
  build

APP_PATH="$(xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
  -clonedSourcePackagesDirPath "$PACKAGE_CACHE" \
  -skipMacroValidation \
  -showBuildSettings 2>/dev/null \
  | awk -F ' = ' '/TARGET_BUILD_DIR/ {build=$2} /WRAPPER_NAME/ {wrapper=$2} END {print build "/" wrapper}')"

xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"
xcrun simctl launch "$SIMULATOR_UDID" "$APP_BUNDLE_ID"
