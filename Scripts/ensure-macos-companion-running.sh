#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROCESS_NAME="${TINKERBLE_COMPANION_PROCESS_NAME:-TinkerbleCompanion}"
WAIT_TIMEOUT="${TINKERBLE_COMPANION_WAIT_TIMEOUT:-20}"
RESTART=0
PROJECT_ROOT=""
PROJECT_ID=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [--restart] [--project-root PATH] [--project-id ID]

Builds the packaged macOS companion app and ensures it is running.

Options:
  --restart   Stop an existing companion process before launching the new build.
  --project-root PATH
              Allow source edits only inside this project directory.
  --project-id ID
              Associate the project directory with this app identifier.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --restart)
      RESTART=1
      shift
      ;;
    --project-root)
      if [[ $# -lt 2 ]]; then
        echo "--project-root requires a path." >&2
        exit 2
      fi
      PROJECT_ROOT="$2"
      shift 2
      ;;
    --project-id)
      if [[ $# -lt 2 ]]; then
        echo "--project-id requires an identifier." >&2
        exit 2
      fi
      PROJECT_ID="$2"
      shift 2
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

if [[ -n "$PROJECT_ROOT" ]]; then
  if [[ ! -d "$PROJECT_ROOT" ]]; then
    echo "Project root does not exist: $PROJECT_ROOT" >&2
    exit 1
  fi
  PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd -P)"
fi

if [[ -n "$PROJECT_ROOT" || -n "$PROJECT_ID" ]]; then
  RESTART=1
fi

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

launch_companion() {
  local attempt=1
  local maximum_attempts=8

  while [[ $attempt -le $maximum_attempts ]]; do
    if open "${OPEN_ARGUMENTS[@]}"; then
      return 0
    fi
    if [[ $attempt -lt $maximum_attempts ]]; then
      sleep 0.25
    fi
    attempt=$((attempt + 1))
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

OPEN_ARGUMENTS=("$APP_BUNDLE")
if [[ -n "$PROJECT_ROOT" || -n "$PROJECT_ID" ]]; then
  OPEN_ARGUMENTS+=(--args)
fi
if [[ -n "$PROJECT_ROOT" ]]; then
  OPEN_ARGUMENTS+=(--project-root "$PROJECT_ROOT")
fi
if [[ -n "$PROJECT_ID" ]]; then
  OPEN_ARGUMENTS+=(--project-id "$PROJECT_ID")
fi
if ! launch_companion; then
  echo "Unable to ask LaunchServices to open $APP_BUNDLE." >&2
  exit 1
fi

if ! wait_for_launch; then
  echo "Timed out waiting for $PROCESS_NAME to listen for socket connections." >&2
  exit 1
fi

echo "Tinkerble companion is running from $APP_BUNDLE."
