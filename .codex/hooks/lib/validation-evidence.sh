#!/bin/bash
# Content-bound validation evidence shared by Stop and pre-commit hooks.
#
# A manifest contains one line per relevant changed file:
#   <sha256-or-DELETED><TAB><path>
#
# This makes validation valid for file contents, not for an arbitrary time
# window. Product Swift, package manifests, the Xcode project, and checked-in
# snapshot baselines participate in the fingerprint.

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -euo pipefail
fi

validation_paths() {
  local mode="${1:-worktree}"
  local tracked=""
  local untracked=""

  case "$mode" in
    worktree)
      tracked=$(git diff --name-only --diff-filter=ACMRD HEAD 2>/dev/null || true)
      untracked=$(git ls-files --others --exclude-standard 2>/dev/null || true)
      ;;
    staged)
      tracked=$(git diff --cached --name-only --diff-filter=ACMRD 2>/dev/null || true)
      ;;
    *)
      echo "Unknown validation mode: $mode" >&2
      return 2
      ;;
  esac

  printf '%s\n%s\n' "$tracked" "$untracked" |
    sed '/^$/d' |
    grep -E '(\.swift$|(^|/)Package\.swift$|^FitnessApp\.xcodeproj/project\.pbxproj$|/Tests?/.*__Snapshots__/.*\.png$)' |
    sort -u || true
}

validation_hash_for_path() {
  local mode="$1"
  local path="$2"

  if [ "$mode" = "staged" ]; then
    if git cat-file -e ":$path" 2>/dev/null; then
      git show ":$path" | shasum -a 256 | awk '{print $1}'
    else
      printf 'DELETED\n'
    fi
    return
  fi

  if [ -f "$path" ]; then
    shasum -a 256 "$path" | awk '{print $1}'
  else
    printf 'DELETED\n'
  fi
}

write_validation_manifest() {
  local output="$1"
  local mode="${2:-worktree}"
  local path=""
  local hash=""
  local temporary="${output}.tmp.$$"

  : > "$temporary"
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    hash=$(validation_hash_for_path "$mode" "$path")
    printf '%s\t%s\n' "$hash" "$path" >> "$temporary"
  done <<< "$(validation_paths "$mode")"

  sort -t $'\t' -k2,2 "$temporary" > "$output"
  rm -f "$temporary"
}

validation_manifest_fingerprint() {
  local manifest="$1"
  if [ ! -f "$manifest" ]; then
    return 1
  fi
  shasum -a 256 "$manifest" | awk '{print $1}'
}

validation_manifest_matches_worktree() {
  local manifest="$1"
  local temporary=""

  [ -f "$manifest" ] || return 1
  temporary=$(mktemp)
  write_validation_manifest "$temporary" worktree
  cmp -s "$manifest" "$temporary"
  local result=$?
  rm -f "$temporary"
  return "$result"
}

validation_manifest_covers_staged() {
  local manifest="$1"
  local path=""
  local hash=""

  [ -f "$manifest" ] || return 1
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    hash=$(validation_hash_for_path staged "$path")
    if ! grep -Fqx "${hash}"$'\t'"${path}" "$manifest"; then
      return 1
    fi
  done <<< "$(validation_paths staged)"
}

validation_stamp_matches_manifest() {
  local stamp="$1"
  local manifest="$2"
  local fingerprint=""

  [ -f "$stamp" ] || return 1
  [ -f "$manifest" ] || return 1
  grep -qiE '(^|[[:space:]])result:[[:space:]]*PASS|TEST SUCCEEDED|all passed' "$stamp" || return 1
  fingerprint=$(validation_manifest_fingerprint "$manifest")
  grep -q "source_fingerprint:[[:space:]]*${fingerprint}" "$stamp"
}

validation_usage() {
  cat <<'EOF'
Usage:
  validation-evidence.sh paths [worktree|staged]
  validation-evidence.sh write <manifest> [worktree|staged]
  validation-evidence.sh verify <manifest> [worktree|staged]
  validation-evidence.sh fingerprint <manifest>
  validation-evidence.sh stamp-matches <stamp> <manifest>
EOF
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  command="${1:-}"
  case "$command" in
    paths)
      validation_paths "${2:-worktree}"
      ;;
    write)
      [ "$#" -ge 2 ] || { validation_usage >&2; exit 2; }
      write_validation_manifest "$2" "${3:-worktree}"
      ;;
    verify)
      [ "$#" -ge 2 ] || { validation_usage >&2; exit 2; }
      if [ "${3:-worktree}" = "staged" ]; then
        validation_manifest_covers_staged "$2"
      else
        validation_manifest_matches_worktree "$2"
      fi
      ;;
    fingerprint)
      [ "$#" -eq 2 ] || { validation_usage >&2; exit 2; }
      validation_manifest_fingerprint "$2"
      ;;
    stamp-matches)
      [ "$#" -eq 3 ] || { validation_usage >&2; exit 2; }
      validation_stamp_matches_manifest "$2" "$3"
      ;;
    *)
      validation_usage >&2
      exit 2
      ;;
  esac
fi
