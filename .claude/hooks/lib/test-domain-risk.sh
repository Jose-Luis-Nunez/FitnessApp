#!/bin/bash
# Domain baseline for risk-based test selection.
# Output: low | medium | high | blocker

test_domain_risk_rank() {
  case "$1" in
    low) echo 0 ;;
    medium) echo 1 ;;
    high) echo 2 ;;
    blocker) echo 3 ;;
    *) return 2 ;;
  esac
}

classify_test_domain_path() {
  local path="$1"

  case "$path" in
    *Feedback*|*/Feedback/*)
      printf 'low\n'
      ;;
    FitnessApp/Features/BottomBar/Profile/*|Packages/FitnessProfile/*|Packages/FitnessFriends/*|Packages/FitnessUI/*Profile*)
      printf 'low\n'
      ;;
    Packages/FitnessTraining/*|Packages/FitnessExercise/*|Packages/FitnessPersistenceUI/*|FitnessApp/Features/Training/*|FitnessAppUITests/Tests/Training*|FitnessAppUITests/Tests/BilateralExercise*|*Exercise*|Packages/FitnessUI/*Card*|Packages/FitnessUI/*Category*|Packages/FitnessUI/*Idle*|Packages/FitnessUI/*Inactive*|Packages/FitnessUI/*SetTile*|Packages/FitnessUI/*Training*)
      printf 'blocker\n'
      ;;
    Packages/FitnessWorkouts/*|*Workout*)
      printf 'high\n'
      ;;
    Packages/FitnessAnalytics/*|*Analytics*)
      printf 'high\n'
      ;;
    *)
      printf 'medium\n'
      ;;
  esac
}

classify_test_domain_paths() {
  local highest="low"
  local highest_rank=0
  local path=""
  local risk=""
  local rank=0
  local seen_product=false

  while IFS= read -r path; do
    [ -z "$path" ] && continue
    case "$path" in
      FitnessApp/*|Packages/*|FitnessAppUITests/*)
        seen_product=true
        ;;
      *)
        continue
        ;;
    esac
    risk=$(classify_test_domain_path "$path")
    rank=$(test_domain_risk_rank "$risk")
    if [ "$rank" -gt "$highest_rank" ]; then
      highest="$risk"
      highest_rank="$rank"
    fi
  done

  if [ "$seen_product" = false ]; then
    printf 'medium\n'
    return
  fi

  printf '%s\n' "$highest"
}

test_domain_changed_paths() {
  local mode="${1:-worktree}"

  if [ "$mode" = "staged" ]; then
    git diff --cached --name-only --diff-filter=ACMRD 2>/dev/null || true
    return
  fi

  {
    git diff --name-only --diff-filter=ACMRD HEAD 2>/dev/null
    git ls-files --others --exclude-standard 2>/dev/null
  } | grep -v '^$' | sort -u || true
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -euo pipefail
  case "${1:-classify}" in
    classify)
      test_domain_changed_paths "${2:-worktree}" | classify_test_domain_paths
      ;;
    classify-paths)
      classify_test_domain_paths
      ;;
    classify-path)
      [ "$#" -eq 2 ] || exit 2
      classify_test_domain_path "$2"
      ;;
    rank)
      [ "$#" -eq 2 ] || exit 2
      test_domain_risk_rank "$2"
      ;;
    *)
      echo "Usage: test-domain-risk.sh classify [worktree|staged] | classify-paths | classify-path <path> | rank <risk>" >&2
      exit 2
      ;;
  esac
fi
