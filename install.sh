#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${TINKERBLE_REPO_URL:-https://github.com/edwardsanchez/Tinkerble.git}"
INSTALL_DIR="${TINKERBLE_INSTALL_DIR:-$HOME/.local/bin}"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$INSTALL_DIR"

git clone --depth 1 "$REPO_URL" "$TMP_DIR/Tinkerble"
swift build --package-path "$TMP_DIR/Tinkerble" -c release --product tinkerble

BIN_PATH="$(swift build --package-path "$TMP_DIR/Tinkerble" -c release --show-bin-path)/tinkerble"
install -m 0755 "$BIN_PATH" "$INSTALL_DIR/tinkerble"

cat <<EOF
Installed tinkerble to $INSTALL_DIR/tinkerble.

Run:
  cd /path/to/MyApp
  tinkerble install

If tinkerble is not found, add this to your shell profile:
  export PATH="$INSTALL_DIR:\$PATH"
EOF
