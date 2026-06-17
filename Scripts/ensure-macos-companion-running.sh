#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROCESS_NAME="${TINKERBLE_COMPANION_PROCESS_NAME:-TinkerbleCompanion}"
WAIT_TIMEOUT="${TINKERBLE_COMPANION_WAIT_TIMEOUT:-20}"
RESTART=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [--restart]

Builds the packaged macOS companion app and ensures it is running.

Options:
  --restart   Stop an existing companion process before launching the new build.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --restart)
      RESTART=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "${TINKERBLE_COMPANION_AUTOLAUNCH:-1}" == "0" ]]; then
  echo "Tinkerble companion autolaunch disabled."
  exit 0
fi

running_pids() {
  pgrep -x "$PROCESS_NAME" || true
}

is_companion_listening() {
  local pid
  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    if lsof -Pan -p "$pid" -iTCP -sTCP:LISTEN >/dev/null 2>&1; then
      return 0
    fi
  done < <(running_pids)

  return 1
}

wait_for_process_exit() {
  local deadline=$((SECONDS + WAIT_TIMEOUT))

  while [[ $SECONDS -lt $deadline ]]; do
    if [[ -z "$(running_pids)" ]]; then
      return 0
    fi
    sleep 0.25
  done

  return 1
}

wait_for_launch() {
  local deadline=$((SECONDS + WAIT_TIMEOUT))

  while [[ $SECONDS -lt $deadline ]]; do
    if [[ -n "$(running_pids)" ]] && is_companion_listening; then
      return 0
    fi
    sleep 0.25
  done

  return 1
}

PACKAGE_OUTPUT="$("$ROOT_DIR/Scripts/package-macos-companion.sh")"
APP_BUNDLE="$(printf "%s\n" "$PACKAGE_OUTPUT" | tail -n 1)"

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "Packaged companion app not found: $APP_BUNDLE" >&2
  exit 1
fi

if [[ "$RESTART" == "1" && -n "$(running_pids)" ]]; then
  pkill -x "$PROCESS_NAME"
  if ! wait_for_process_exit; then
    echo "Timed out waiting for existing $PROCESS_NAME to exit." >&2
    exit 1
  fi
fi

if [[ -z "$(running_pids)" ]]; then
  open "$APP_BUNDLE"
else
  open "$APP_BUNDLE"
fi

if ! wait_for_launch; then
  echo "Timed out waiting for $PROCESS_NAME to listen for socket connections." >&2
  exit 1
fi

echo "Tinkerble companion is running from $APP_BUNDLE."
