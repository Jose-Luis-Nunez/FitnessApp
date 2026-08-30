#!/bin/bash
# buildApp.sh
#
# Build, install, and launch the FitnessApp on ONE target — either a
# connected physical iPhone (via devicectl) or a booted iOS Simulator
# (via simctl). Single-target by design so the user can deploy a
# version to one runtime and compare it against the other.
#
# Usage:
#   ./scripts/buildApp.sh              # auto: the only available target
#                                    # (errors if both available — pick)
#   ./scripts/buildApp.sh --device     # physical iPhone only
#   ./scripts/buildApp.sh --sim        # booted simulator only
#   ./scripts/buildApp.sh -h | --help  # this help
#
# Prerequisites:
#   - Physical iPhone (optional): paired, Developer Mode enabled,
#     blessed in Xcode at least once for development.
#   - Simulator (optional): booted in Xcode or via `xcrun simctl boot`.
#     Preferred name defaults to "iPhone 17 Pro Max", override with
#     PREFERRED_SIM_NAME=…
#
# Why this script exists: xcodebuild, devicectl, simctl, and xctrace
# each use a different identifier for the same target (destination name
# vs Core Device UUID vs simulator UDID vs ECID). This script handles
# every lookup so callers don't have to.

set -euo pipefail

# ---- Args ----
MODE="auto"
while [ $# -gt 0 ]; do
  case "$1" in
    -d|--device) MODE="device"; shift ;;
    -s|--sim|--simulator) MODE="sim"; shift ;;
    -h|--help)
      sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 2 ;;
  esac
done

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "ERROR: not inside a git repository." >&2
  exit 1
}
cd "$REPO_ROOT"

# Same pinned toolchain as test-affected-packages.sh and build-and-test.mdc.
# This pointed at Xcode.app, which does not exist, so every run died at the
# first xcodebuild call with a message about the toolchain rather than the app.
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Users/jose.nunez/Downloads/Xcode-beta.app/Contents/Developer}"
# Derived from the repo root, not from `${BASH_SOURCE[0]}`: the `cd` above has
# already happened, so a relative invocation path (`../scripts/buildApp.sh`)
# would resolve against the wrong directory and abort under `set -e`.
SCRIPT_DIR="$REPO_ROOT/scripts"
# shellcheck source=lib/derived-data.sh
. "$SCRIPT_DIR/lib/derived-data.sh"
if [ ! -d "$DEVELOPER_DIR" ]; then
  echo "ERROR: DEVELOPER_DIR does not exist: $DEVELOPER_DIR" >&2
  echo "       Set DEVELOPER_DIR to your Xcode's Contents/Developer and re-run." >&2
  exit 1
fi
export PATH="$DEVELOPER_DIR/usr/bin:$PATH"

SCHEME="${SCHEME:-FitnessApp}"
BUNDLE_ID="${BUNDLE_ID:-com.fitnesspro.FitnessTeam}"
PREFERRED_SIM_NAME="${PREFERRED_SIM_NAME:-iPhone 17 Pro Max}"

# ---- Discovery ----
# Only query each toolchain when its target is in scope. Skips ~0.3s
# per unused query in explicit modes.
DEVICE_LINE=""
SIM_UUID=""
if [ "$MODE" != "sim" ]; then
  DEVICE_LINE=$(xcrun devicectl list devices 2>/dev/null | awk '/connected/ {print; exit}')
fi
if [ "$MODE" != "device" ]; then
  SIM_UUID=$(xcrun simctl list devices booted 2>/dev/null \
    | grep -F "$PREFERRED_SIM_NAME (" \
    | grep "(Booted)" \
    | head -1 \
    | sed -E 's/.*\(([0-9A-F-]+)\) \(Booted\).*/\1/')
fi

DEVICE_AVAILABLE=$([ -n "$DEVICE_LINE" ] && echo 1 || echo 0)
SIM_AVAILABLE=$([ -n "$SIM_UUID" ] && echo 1 || echo 0)

# Resolve auto-mode: pick the only available target; refuse if both are up.
if [ "$MODE" = "auto" ]; then
  if [ "$DEVICE_AVAILABLE" = "1" ] && [ "$SIM_AVAILABLE" = "1" ]; then
    echo "ERROR: both iPhone and simulator are available — pick one explicitly." >&2
    echo "  ./scripts/buildApp.sh --device   (iPhone von Jose)" >&2
    echo "  ./scripts/buildApp.sh --sim      ($PREFERRED_SIM_NAME)" >&2
    exit 1
  elif [ "$DEVICE_AVAILABLE" = "1" ]; then
    MODE="device"
  elif [ "$SIM_AVAILABLE" = "1" ]; then
    MODE="sim"
  else
    echo "ERROR: no targets available. Plug in an iPhone OR boot the '$PREFERRED_SIM_NAME' simulator." >&2
    echo "  Diagnose: xcrun devicectl list devices  /  xcrun simctl list devices booted" >&2
    exit 1
  fi
fi

# Explicit-mode: requested target must actually be available.
if [ "$MODE" = "device" ] && [ "$DEVICE_AVAILABLE" = "0" ]; then
  echo "ERROR: --device requested but no iPhone in 'connected' state." >&2
  echo "  Diagnose: xcrun devicectl list devices" >&2
  exit 1
fi
if [ "$MODE" = "sim" ] && [ "$SIM_AVAILABLE" = "0" ]; then
  echo "ERROR: --sim requested but no '$PREFERRED_SIM_NAME' simulator booted." >&2
  echo "  Diagnose: xcrun simctl list devices booted" >&2
  exit 1
fi

START_TS=$(date +%s)

# ---- Physical iPhone ----
deploy_device() {
  local DEVICE_UUID DEVICE_NAME APP_PATH
  DEVICE_UUID=$(echo "$DEVICE_LINE" | awk '{ for (i=1; i<=NF; i++) if ($i == "connected") { print $(i-1); exit } }')
  DEVICE_NAME=$(echo "$DEVICE_LINE" | sed -E 's/  +.*$//')

  if [ -z "$DEVICE_UUID" ]; then
    echo "WARN: could not parse Core Device UUID, skipping device." >&2
    echo "  Raw line: $DEVICE_LINE" >&2
    return 0
  fi

  echo "=== Device: $DEVICE_NAME ($DEVICE_UUID) ==="

  echo "[1/3] Building (iphoneos)..."
  xcodebuild build \
    -scheme "$SCHEME" \
    -destination "platform=iOS,name=$DEVICE_NAME" \
    -allowProvisioningUpdates \
    -skipPackagePluginValidation \
    -skipMacroValidation \
    -quiet
  echo "  ✓ build succeeded"

  # Resolved by WorkspacePath, not by newest mtime: a leftover worktree's
  # derived data outranks this checkout's by date and would be installed instead.
  APP_PATH="$(fitness_app_bundle Debug-iphoneos "$SCHEME" || true)"
  if [ -z "$APP_PATH" ]; then
    echo "ERROR: built .app not found under Debug-iphoneos for this checkout." >&2
    return 1
  fi

  # xcodebuild has reported success while silently skipping the app target;
  # installing that leaves the device running code that is not the source.
  "$SCRIPT_DIR/assert-app-build-current.sh" Debug-iphoneos || return 1

  echo "[2/3] Installing..."
  xcrun devicectl device install app --device "$DEVICE_UUID" "$APP_PATH" 2>&1 \
    | grep -E "App installed|error" \
    || { echo "ERROR: install did not report success." >&2; return 1; }

  echo "[3/3] Launching..."
  xcrun devicectl device process launch --device "$DEVICE_UUID" "$BUNDLE_ID" 2>&1 \
    | grep -E "Launched|error"
  echo ""
}

# ---- Simulator ----
deploy_simulator() {
  local APP_PATH
  echo "=== Simulator: $PREFERRED_SIM_NAME ($SIM_UUID) ==="

  echo "[1/3] Building (iphonesimulator)..."
  xcodebuild build \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,id=$SIM_UUID" \
    -skipPackagePluginValidation \
    -skipMacroValidation \
    -quiet
  echo "  ✓ build succeeded"

  # See deploy_device: selection is by WorkspacePath, and the freshness of the
  # bundle is asserted before it is installed.
  APP_PATH="$(fitness_app_bundle Debug-iphonesimulator "$SCHEME" || true)"
  if [ -z "$APP_PATH" ]; then
    echo "ERROR: built .app not found under Debug-iphonesimulator for this checkout." >&2
    return 1
  fi

  "$SCRIPT_DIR/assert-app-build-current.sh" Debug-iphonesimulator || return 1

  echo "[2/3] Installing..."
  xcrun simctl install "$SIM_UUID" "$APP_PATH"

  echo "[3/3] Launching..."
  xcrun simctl launch "$SIM_UUID" "$BUNDLE_ID"
  echo ""
}

case "$MODE" in
  device) deploy_device ;;
  sim)    deploy_simulator ;;
esac

END_TS=$(date +%s)
echo "Done in $((END_TS - START_TS))s."
