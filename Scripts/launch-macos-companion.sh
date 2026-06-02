#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_OUTPUT="$("$ROOT_DIR/Scripts/package-macos-companion.sh")"
APP_BUNDLE="$(printf "%s\n" "$PACKAGE_OUTPUT" | tail -n 1)"

open -n "$APP_BUNDLE"
echo "Launched $APP_BUNDLE"
