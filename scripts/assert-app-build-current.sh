#!/bin/bash
# Fails when the built app bundle is older than the newest app source.
#
# Why this exists: xcodebuild has repeatedly reported "BUILD SUCCEEDED" for this
# project while silently skipping the app target — packages were rebuilt, the app
# binary was left untouched, and the simulator then ran stale code. It is not
# reproducible on demand (a deliberate probe rebuilt correctly), so it cannot be
# fixed here; what it can be is loud instead of silent. A stale binary looks
# exactly like "my change had no effect", which costs a full debugging detour.
#
# Scope: Swift sources of the app target and the packages it links. Asset
# catalogs, Info.plist and package manifests are NOT covered — a resource-only
# stale build still passes, so a pass is not a general freshness proof.
#
# Usage: scripts/assert-app-build-current.sh [configuration]
#   configuration defaults to Debug-iphonesimulator.
set -euo pipefail

CONFIGURATION="${1:-Debug-iphonesimulator}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/derived-data.sh
. "$REPO_ROOT/scripts/lib/derived-data.sh"

APP_BUNDLE="$(fitness_app_bundle "$CONFIGURATION" || true)"
if [ -z "$APP_BUNDLE" ]; then
  echo "assert-app-build-current: no built app for '$CONFIGURATION' belonging to $REPO_ROOT." >&2
  echo "  Derived data of other checkouts is ignored on purpose." >&2
  exit 1
fi

# The Swift code lives in the debug dylib when Xcode builds with that layout;
# the top-level executable is then only a launcher stub that can be re-signed
# without relinking. Compare against whichever artefact is OLDER, so a stale
# dylib behind a freshly signed stub cannot pass.
REFERENCE="$APP_BUNDLE/$(basename "$APP_BUNDLE" .app)"
DEBUG_DYLIB="$REFERENCE.debug.dylib"
if [ -f "$DEBUG_DYLIB" ] && [ "$DEBUG_DYLIB" -ot "$REFERENCE" ]; then
  REFERENCE="$DEBUG_DYLIB"
fi
if [ ! -f "$REFERENCE" ]; then
  echo "assert-app-build-current: no executable inside $APP_BUNDLE." >&2
  exit 1
fi

SOURCE_ROOTS=("$REPO_ROOT/FitnessApp")
for sources in "$REPO_ROOT"/Packages/*/Sources; do
  [ -d "$sources" ] && SOURCE_ROOTS+=("$sources")
done

# `find` failing must not read as "nothing is newer": without this a bad path
# would exit 0 with empty output and the check would print OK.
if ! NEWER="$(find "${SOURCE_ROOTS[@]}" -name '*.swift' -type f \
      -not -path '*/.build/*' -newer "$REFERENCE" -print0 | tr '\0' '\n')"; then
  echo "assert-app-build-current: could not scan sources under $REPO_ROOT." >&2
  exit 1
fi

if [ -n "$NEWER" ]; then
  # `find -exec` rather than xargs: a path containing a space would otherwise be
  # split and stat'ed as two nonexistent files.
  NEWEST="$(find "${SOURCE_ROOTS[@]}" -name '*.swift' -type f \
      -not -path '*/.build/*' -newer "$REFERENCE" \
      -exec stat -f '%m %N' {} + | sort -rn | head -1 | cut -d' ' -f2-)"
  echo "assert-app-build-current: STALE BUILD for '$CONFIGURATION'." >&2
  echo "  Built:  $(date -r "$REFERENCE" '+%Y-%m-%d %H:%M:%S')  ${REFERENCE#"$REPO_ROOT"/}" >&2
  echo "  Newer:  $(date -r "$NEWEST" '+%Y-%m-%d %H:%M:%S')  ${NEWEST#"$REPO_ROOT"/}" >&2
  echo "          ($(printf '%s\n' "$NEWER" | wc -l | tr -d ' ') source files newer than the build)" >&2
  echo >&2
  echo "  xcodebuild reported success without rebuilding the app target." >&2
  echo "  Recover with: xcodebuild clean -project FitnessApp.xcodeproj -scheme '<scheme>'" >&2
  exit 1
fi

echo "assert-app-build-current: OK — $CONFIGURATION is newer than every app source."
