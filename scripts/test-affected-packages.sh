#!/bin/bash
# Run affected module tests through one shared SwiftPM graph. Xcode coordinates
# build parallelism globally; fast tests run natively and platform contracts use
# the pinned simulator.

set -euo pipefail

MODE="affected"
XCODE_BUILD_JOBS=6
MAX_TEST_WORKERS=6
XCODE_ACTION="test"
ENABLE_COMPILATION_CACHE=0
SHOW_BUILD_TIMING=0
LIST_ONLY=0
RESULT_BUNDLE_DIR=""

usage() {
  cat >&2 <<'EOF'
Usage: scripts/test-affected-packages.sh [options] [Package ...]

With no mode option, selected packages run in the appropriate phases: native
fast tests, pinned-iOS integration tests, and separated snapshot tests.

Modes:
  --fast                    Native macOS fast tests only
  --integration             Pinned iOS integration/platform tests only
  --snapshots               Pinned iOS snapshot tests only
  --pre-merge               Complete pinned-iOS pre-merge test plan

Options:
  --jobs N                  Globally coordinated Xcode build jobs (default: 6)
  --xcode-jobs N            Alias for --jobs
  --test-workers N          Maximum parallel Xcode test workers (default: 6)
  --compilation-cache       Enable Xcode's compilation cache
  --diagnose                Include Xcode's build timing summary
  --build-for-testing       Build reusable test products without running tests
  --test-without-building   Re-run matching products after an unchanged build
  --result-bundle DIR       Keep the .xcresult bundles in DIR instead of a
                            temporary directory that is deleted on exit. Use
                            this whenever the run has to serve as evidence:
                            without it the counts exist only on stdout and
                            cannot be verified afterwards.
  --list                    Print the resolved phase/target schedule only
  --record                  Re-record snapshot baselines instead of comparing.
                            Selects the recording test plan, which is the only
                            way the runner process sees RECORD_SNAPSHOTS: a
                            plan does not inherit this shell's environment and
                            does not expand build settings in its own entries.
                            Prints every baseline the run changed.
EOF
}

packages=()
# Must precede the parse loop: initialising it further down silently reset the
# flag the loop had just set.
RECORD_SNAPSHOTS_MODE=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --fast|--integration|--snapshots|--pre-merge)
      requested_mode="${1#--}"
      if [ "$MODE" != "affected" ]; then
        echo "ERROR: choose exactly one test mode." >&2
        exit 2
      fi
      MODE="$requested_mode"
      shift
      ;;
    --record)
      RECORD_SNAPSHOTS_MODE=1
      shift
      ;;
    --jobs|--xcode-jobs)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      XCODE_BUILD_JOBS="$2"
      shift 2
      ;;
    --test-workers)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      MAX_TEST_WORKERS="$2"
      shift 2
      ;;
    --compilation-cache)
      ENABLE_COMPILATION_CACHE=1
      shift
      ;;
    --diagnose)
      SHOW_BUILD_TIMING=1
      shift
      ;;
    --build-for-testing)
      XCODE_ACTION="build-for-testing"
      shift
      ;;
    --test-without-building)
      XCODE_ACTION="test-without-building"
      shift
      ;;
    --result-bundle)
      # Reject a following flag rather than treating it as the directory name:
      # `--result-bundle --list` otherwise fails inside `mkdir` with a message
      # that names the wrong problem.
      [ "$#" -ge 2 ] || { usage; exit 2; }
      case "$2" in -*) echo "ERROR: --result-bundle needs a directory." >&2; usage; exit 2 ;; esac
      RESULT_BUNDLE_DIR="$2"
      shift 2
      ;;
    --list)
      LIST_ONLY=1
      shift
      ;;
    --)
      shift
      while [ "$#" -gt 0 ]; do
        packages+=("$1")
        shift
      done
      ;;
    -*)
      echo "ERROR: unknown option '$1'." >&2
      usage
      exit 2
      ;;
    *)
      packages+=("$1")
      shift
      ;;
  esac
done

for numeric_value in "$XCODE_BUILD_JOBS" "$MAX_TEST_WORKERS"; do
  case "$numeric_value" in
    ''|*[!0-9]*|0)
      echo "ERROR: job and worker counts must be positive integers." >&2
      exit 2
      ;;
  esac
done

all_packages=(
  FitnessResources FitnessCore FitnessUI FitnessAnalytics FitnessTraining
  FitnessExercise FitnessPersistenceUI FitnessSchedule FitnessProfile
  FitnessStorage FitnessWorkouts FitnessFriends
)
if [ "${#packages[@]}" -eq 0 ]; then
  packages=("${all_packages[@]}")
fi

is_known_package() {
  case "$1" in
    FitnessResources|FitnessCore|FitnessUI|FitnessAnalytics|FitnessTraining|FitnessExercise|FitnessPersistenceUI|FitnessSchedule|FitnessProfile|FitnessStorage|FitnessWorkouts|FitnessFriends)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

add_unique() {
  array_name="$1"
  value="$2"
  eval "current_values=(\"\${${array_name}[@]-}\")"
  for current_value in "${current_values[@]}"; do
    [ "$current_value" = "$value" ] && return 0
  done
  eval "$array_name+=(\"$value\")"
}

fast_targets=()
integration_targets=()
snapshot_targets=()
FAST_DURATION=0
INTEGRATION_DURATION=0
SNAPSHOT_DURATION=0
PREMERGE_DURATION=0

for package in "${packages[@]}"; do
  if ! is_known_package "$package"; then
    echo "ERROR: unknown package '$package'." >&2
    exit 2
  fi

  if [ "$MODE" = "affected" ] || [ "$MODE" = "fast" ]; then
    case "$package" in
      FitnessResources) add_unique fast_targets FitnessResourcesTests ;;
      FitnessCore) add_unique fast_targets FitnessCoreTests ;;
      FitnessUI) add_unique fast_targets FitnessUITests ;;
      FitnessAnalytics) add_unique fast_targets FitnessAnalyticsTests ;;
      FitnessTraining) add_unique fast_targets FitnessTrainingTests ;;
      FitnessExercise) add_unique fast_targets FitnessExerciseTests ;;
      FitnessSchedule) add_unique fast_targets FitnessScheduleTests ;;
      FitnessProfile) add_unique fast_targets FitnessProfileTests ;;
      FitnessStorage) add_unique fast_targets FitnessStorageTests ;;
    esac
  fi

  if [ "$MODE" = "affected" ] || [ "$MODE" = "integration" ]; then
    case "$package" in
      FitnessStorage) add_unique integration_targets FitnessStorageMigrationTests ;;
      FitnessWorkouts) add_unique integration_targets FitnessWorkoutsTests ;;
      FitnessFriends) add_unique integration_targets FitnessFriendsTests ;;
      FitnessAnalytics) add_unique integration_targets FitnessAnalyticsIntegrationTests ;;
      FitnessExercise) add_unique integration_targets FitnessExerciseIntegrationTests ;;
      FitnessPersistenceUI) add_unique integration_targets FitnessPersistenceUIIntegrationTests ;;
    esac
  fi

  if [ "$MODE" = "affected" ] || [ "$MODE" = "snapshots" ]; then
    case "$package" in
      FitnessTraining) add_unique snapshot_targets FitnessTrainingSnapshotTests ;;
      FitnessPersistenceUI) add_unique snapshot_targets FitnessPersistenceUISnapshotTests ;;
    esac
  fi
done

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "ERROR: not inside the FitnessApp repository." >&2
  exit 1
}
WORKSPACE="$REPO_ROOT/FitnessModules.xcworkspace"
SCHEME="FitnessModulesTests"
XCODE_DEVELOPER_DIR="/Users/jose.nunez/Downloads/Xcode-beta.app/Contents/Developer"
export DEVELOPER_DIR="$XCODE_DEVELOPER_DIR"
export PATH="$XCODE_DEVELOPER_DIR/usr/bin:$PATH"

MAC_DESTINATION="platform=macOS,arch=arm64"
IOS_DESTINATION="platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.0"
# A temporary directory is right for a developer loop and wrong for evidence:
# the bundle is the only artifact that can be checked after the fact, and the
# summary printed to stdout cannot. `--result-bundle` keeps it.
if [ -n "$RESULT_BUNDLE_DIR" ]; then
  mkdir -p "$RESULT_BUNDLE_DIR"
  RESULT_DIRECTORY=$(cd "$RESULT_BUNDLE_DIR" && pwd)
else
  RESULT_DIRECTORY=$(mktemp -d "${TMPDIR:-/tmp}/fitness-module-tests.XXXXXX")
  trap 'rm -rf "$RESULT_DIRECTORY"' EXIT
fi

print_targets() {
  phase="$1"
  platform="$2"
  shift 2
  if [ "$#" -eq 0 ]; then
    return
  fi
  printf '%-14s | %-19s | %s\n' "$phase" "$platform" "$*"
}

echo "Shared graph: Packages/Package.swift"
echo "Xcode build jobs: $XCODE_BUILD_JOBS (one globally coordinated xcodebuild per phase)"
echo "Maximum test workers: $MAX_TEST_WORKERS"
echo "Execution policy:"
echo "  Fast        — up to $MAX_TEST_WORKERS native test workers"
echo "  Integration — one simulator, no parallel clones"
echo "  Snapshots   — one simulator, no parallel clones"
echo "Resolved schedule:"
if [ "${#fast_targets[@]}" -gt 0 ]; then
  print_targets "Fast" "native macOS" "${fast_targets[@]}"
fi
if [ "${#integration_targets[@]}" -gt 0 ]; then
  print_targets "Integration" "iOS 26 simulator" "${integration_targets[@]}"
fi
if [ "${#snapshot_targets[@]}" -gt 0 ]; then
  print_targets "Snapshots" "iOS 26 simulator" "${snapshot_targets[@]}"
fi
if [ "$MODE" = "pre-merge" ]; then
  print_targets "Pre-merge" "iOS 26 simulator" "all unit, integration, and snapshot targets"
fi

if [ "$MODE" != "pre-merge" ] &&
   [ "${#fast_targets[@]}" -eq 0 ] &&
   [ "${#integration_targets[@]}" -eq 0 ] &&
   [ "${#snapshot_targets[@]}" -eq 0 ]; then
  echo "ERROR: the selected modules have no targets in the '$MODE' test layer." >&2
  echo "Use the default affected mode or choose the matching --integration/--snapshots layer." >&2
  exit 2
fi

if [ "$LIST_ONLY" -eq 1 ]; then
  exit 0
fi

common_arguments=(
  "$XCODE_ACTION"
  -quiet
  -workspace "$WORKSPACE"
  -scheme "$SCHEME"
  -skipMacroValidation
  -enableCodeCoverage NO
  COMPILER_INDEX_STORE_ENABLE=NO
  -jobs "$XCODE_BUILD_JOBS"
)
if [ "$ENABLE_COMPILATION_CACHE" -eq 1 ]; then
  common_arguments+=(COMPILATION_CACHE_ENABLE_CACHING=YES)
fi
if [ "$SHOW_BUILD_TIMING" -eq 1 ]; then
  common_arguments+=(-showBuildTimingSummary)
fi

run_phase() {
  phase_name="$1"
  test_plan="$2"
  destination="$3"
  parallel_testing="$4"
  shift 4
  targets=("$@")
  if [ "${#targets[@]}" -eq 0 ]; then
    return 0
  fi

  result_bundle="$RESULT_DIRECTORY/$phase_name.xcresult"
  # `xcodebuild` refuses to overwrite an existing bundle and fails with a message
  # naming the path rather than the reuse, so a second run into the same
  # `--result-bundle` directory would look like an unrelated error.
  rm -rf "$result_bundle"
  phase_started_at=$(date +%s)
  echo "START: $phase_name at $(date '+%H:%M:%S')"
  phase_arguments=(
    "${common_arguments[@]}"
    -testPlan "$test_plan"
    -destination "$destination"
    -parallel-testing-enabled "$parallel_testing"
    -maximum-parallel-testing-workers "$MAX_TEST_WORKERS"
    -resultBundlePath "$result_bundle"
  )
  for target in "${targets[@]}"; do
    phase_arguments+=("-only-testing:$target")
  done

  phase_status=0
  xcodebuild "${phase_arguments[@]}" || phase_status=$?
  phase_finished_at=$(date +%s)
  phase_duration=$((phase_finished_at - phase_started_at))
  case "$phase_name" in
    fast) FAST_DURATION="$phase_duration" ;;
    integration) INTEGRATION_DURATION="$phase_duration" ;;
    snapshots) SNAPSHOT_DURATION="$phase_duration" ;;
    pre-merge) PREMERGE_DURATION="$phase_duration" ;;
  esac
  echo "END:   $phase_name at $(date '+%H:%M:%S') — ${phase_duration}s"
  if [ "$XCODE_ACTION" = "test" ] || [ "$XCODE_ACTION" = "test-without-building" ]; then
    if [ -f "$result_bundle/Info.plist" ]; then
      python3 "$REPO_ROOT/scripts/summarize-xcresult.py" "$result_bundle"
    fi
  fi
  return "$phase_status"
}

result=0
total_started_at=$(date +%s)
if [ "$MODE" = "pre-merge" ]; then
  premerge_targets=(
    FitnessResourcesTests FitnessCoreTests FitnessUITests FitnessAnalyticsTests
    FitnessTrainingTests FitnessExerciseTests FitnessScheduleTests
    FitnessProfileTests FitnessStorageTests FitnessStorageMigrationTests FitnessWorkoutsTests
    FitnessFriendsTests FitnessAnalyticsIntegrationTests FitnessExerciseIntegrationTests
    FitnessPersistenceUIIntegrationTests FitnessTrainingSnapshotTests
    FitnessPersistenceUISnapshotTests
  )
  run_phase "pre-merge" "FitnessPreMerge" "$IOS_DESTINATION" NO "${premerge_targets[@]}" || result=1
else
  if [ "${#fast_targets[@]}" -gt 0 ]; then
    run_phase "fast" "FitnessFast" "$MAC_DESTINATION" YES "${fast_targets[@]}" || result=1
  fi
  if [ "${#integration_targets[@]}" -gt 0 ]; then
    run_phase "integration" "FitnessIntegration" "$IOS_DESTINATION" NO "${integration_targets[@]}" || result=1
  fi
  if [ "${#snapshot_targets[@]}" -gt 0 ]; then
    snapshot_plan="FitnessSnapshots"
    if [ "$RECORD_SNAPSHOTS_MODE" -eq 1 ]; then
      snapshot_plan="FitnessSnapshotsRecord"
      baselines_before=$(git status --porcelain -- '*__Snapshots__*' 2>/dev/null || true)
    fi
    snapshot_status=0
    run_phase "snapshots" "$snapshot_plan" "$IOS_DESTINATION" NO "${snapshot_targets[@]}" || snapshot_status=1
    if [ "$RECORD_SNAPSHOTS_MODE" -eq 0 ]; then
      [ "$snapshot_status" -eq 0 ] || result=1
    else
      # In record mode the library reports a failure by design ("record mode is
      # on"), so the exit status cannot tell a successful recording from a run
      # that never started -- a missing test plan also exits 1. The result
      # bundle is no help either: xcodebuild writes one even when it aborts
      # before running anything. The executed test count is the honest signal.
      baselines_after=$(git status --porcelain -- '*__Snapshots__*' 2>/dev/null || true)
      recorded_tests=0
      if [ -f "$RESULT_DIRECTORY/snapshots.xcresult/Info.plist" ] &&
         python3 "$REPO_ROOT/scripts/summarize-xcresult.py" \
           "$RESULT_DIRECTORY/snapshots.xcresult" 2>/dev/null |
           grep -qE '^Logical total: [1-9]'; then
        recorded_tests=1
      fi
      echo
      if [ "$recorded_tests" -eq 0 ]; then
        echo "ERROR: the recording run never executed any test, so nothing was recorded."
        echo "       Check the xcodebuild output above -- a missing test plan or a build"
        echo "       failure looks like an ordinary snapshot failure otherwise."
        result=1
      else
        if [ "$baselines_before" = "$baselines_after" ]; then
          echo "RECORDED: the run executed and no baseline changed -- they were already current."
        else
          echo "RECORDED: the following baselines changed. Inspect every one before validating --"
          echo "a baseline that moved without an intended visual change is a regression."
          printf '%s\n' "$baselines_after" | sed 's/^/  /'
          echo "  Compare with: git diff -- '*__Snapshots__*'"
        fi
        echo "  A recording run proves nothing and is not test evidence; validate on the"
        echo "  settled contents afterwards."
      fi
    fi
  fi
fi

total_finished_at=$(date +%s)
echo "Wall-clock summary:"
[ "$FAST_DURATION" -gt 0 ] && printf '  %-12s %4ss\n' "Fast" "$FAST_DURATION"
[ "$INTEGRATION_DURATION" -gt 0 ] && printf '  %-12s %4ss\n' "Integration" "$INTEGRATION_DURATION"
[ "$SNAPSHOT_DURATION" -gt 0 ] && printf '  %-12s %4ss\n' "Snapshots" "$SNAPSHOT_DURATION"
[ "$PREMERGE_DURATION" -gt 0 ] && printf '  %-12s %4ss\n' "Pre-merge" "$PREMERGE_DURATION"
printf '  %-12s %4ss\n' "Total" "$((total_finished_at - total_started_at))"

exit "$result"
