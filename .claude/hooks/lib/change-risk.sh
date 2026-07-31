#!/bin/bash
# Conservative change-risk classifier for agent validation.
# Output: none | green | yellow | red

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -euo pipefail
fi

CHANGE_RISK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=validation-evidence.sh
source "$CHANGE_RISK_DIR/validation-evidence.sh"

change_diff() {
  local mode="${1:-worktree}"
  local diff=""
  local path=""

  if [ "$mode" = "staged" ]; then
    git diff --cached --diff-filter=ACMR -- '*.swift' '*/Package.swift' 'FitnessApp.xcodeproj/project.pbxproj' 2>/dev/null || true
    return
  fi

  diff=$(git diff HEAD --diff-filter=ACMR -- '*.swift' '*/Package.swift' 'FitnessApp.xcodeproj/project.pbxproj' 2>/dev/null || true)
  printf '%s\n' "$diff"
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    case "$path" in
      *.swift|*/Package.swift|FitnessApp.xcodeproj/project.pbxproj)
        [ -f "$path" ] && sed 's/^/+/' "$path"
        ;;
    esac
  done <<< "$(git ls-files --others --exclude-standard 2>/dev/null || true)"
}

change_risk_rank() {
  case "$1" in
    none) echo 0 ;;
    green) echo 1 ;;
    yellow) echo 2 ;;
    red) echo 3 ;;
    *) return 2 ;;
  esac
}

classify_change_risk() {
  local mode="${1:-worktree}"
  local paths=""
  local swift_paths=""
  local production_swift=""
  local production_count=0
  local package_count=0
  local diff=""
  local added=""
  local path=""
  local green_paths=true

  paths=$(validation_paths "$mode")
  swift_paths=$(printf '%s\n' "$paths" | grep '\.swift$' || true)
  if [ -z "$swift_paths" ]; then
    printf 'none\n'
    return
  fi

  production_swift=$(printf '%s\n' "$swift_paths" | grep -Ev '(^|/)(Tests?|TestSupport)/|Tests?\.swift$' || true)
  production_count=$(printf '%s\n' "$production_swift" | sed '/^$/d' | wc -l | tr -d ' ')
  package_count=$(printf '%s\n' "$production_swift" | awk -F/ '/^Packages\// {print $2}' | sort -u | sed '/^$/d' | wc -l | tr -d ' ')
  diff=$(change_diff "$mode")
  added=$(printf '%s\n' "$diff" | grep '^+' | grep -v '^+++' || true)

  if [ "$production_count" -ge 10 ] || [ "$package_count" -ge 2 ]; then
    printf 'red\n'
    return
  fi

  if printf '%s\n' "$paths" | grep -qE '(^|/)(Schema|Migrations?|Models?|Storage|Services?|Coordinators?|Navigation|Container)/|(^|/)[^/]*(Storage|Service|Coordinator|Container)\.swift$|(^|/)Package\.swift$|^FitnessApp\.xcodeproj/project\.pbxproj$'; then
    printf 'red\n'
    return
  fi

  if printf '%s\n' "$added" | grep -qE '@Model\b|@ModelActor\b|#Predicate\b|@Query\b|MigrationStage|ModelContainer|NavigationDestination|Container\.shared|\bactor[[:space:]]|\bdistributed[[:space:]]+actor\b'; then
    printf 'red\n'
    return
  fi

  if [ "$production_count" -eq 0 ]; then
    printf 'green\n'
    return
  fi

  if [ "$production_count" -le 2 ]; then
    while IFS= read -r path; do
      [ -z "$path" ] && continue
      case "$path" in
        *View.swift|*/FitnessUI/Sources/FitnessUI/AppStyle.swift|*Style.swift)
          ;;
        *)
          green_paths=false
          ;;
      esac
    done <<< "$production_swift"

    if [ "$green_paths" = true ] &&
       ! printf '%s\n' "$added" | grep -qE '@State\b|@StateObject\b|@Environment\b|@Query\b|#Predicate\b|@Observable\b|\bTask[[:space:]\{\(]|\basync\b|\bawait\b|modelContext|navigationDestination|fullScreenCover|\.sheet\('; then
      printf 'green\n'
      return
    fi
  fi

  printf 'yellow\n'
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "${1:-classify}" in
    classify)
      classify_change_risk "${2:-worktree}"
      ;;
    rank)
      [ "$#" -eq 2 ] || exit 2
      change_risk_rank "$2"
      ;;
    *)
      echo "Usage: change-risk.sh classify [worktree|staged] | rank <risk>" >&2
      exit 2
      ;;
  esac
fi
