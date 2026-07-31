#!/bin/bash
# Run each requested package test action exactly once with the pinned toolchain.

set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "Usage: scripts/test-affected-packages.sh <Package> [...]" >&2
  exit 2
fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "ERROR: not inside the FitnessApp repository." >&2
  exit 1
}

XCODE_DEVELOPER_DIR="/Users/jose.nunez/Downloads/Xcode-beta.app/Contents/Developer"
export DEVELOPER_DIR="$XCODE_DEVELOPER_DIR"
export PATH="$XCODE_DEVELOPER_DIR/usr/bin:$PATH"

DESTINATION="platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.0"
RESULT=0

scheme_for_package() {
  case "$1" in
    FitnessTraining) printf 'FitnessTraining-Package\n' ;;
    FitnessCore|FitnessExercise|FitnessAnalytics|FitnessStorage|FitnessProfile|FitnessUI|FitnessPersistenceUI|FitnessFriends|FitnessResources|FitnessSchedule|FitnessTestSupport|FitnessWorkouts)
      printf '%s\n' "$1"
      ;;
    *)
      echo "ERROR: unknown package '$1'." >&2
      return 2
      ;;
  esac
}

for package in "$@"; do
  package_dir="$REPO_ROOT/Packages/$package"
  if [ ! -f "$package_dir/Package.swift" ]; then
    echo "ERROR: package manifest missing for '$package'." >&2
    RESULT=1
    continue
  fi

  scheme=$(scheme_for_package "$package") || {
    RESULT=1
    continue
  }

  echo "Testing $package with scheme $scheme"
  if ! (
    cd "$package_dir"
    xcodebuild test -quiet \
      -scheme "$scheme" \
      -destination "$DESTINATION" \
      -skipMacroValidation
  ); then
    RESULT=1
  fi
done

exit "$RESULT"
