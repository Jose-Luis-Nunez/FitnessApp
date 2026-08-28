#!/bin/bash
# Content-bound validation evidence shared by final validation and pre-commit.
#
# A manifest contains one line per changed candidate file:
#   <sha256-or-DELETED><TAB><path>
#
# This makes validation valid for the complete reviewed/tested candidate, not
# for an arbitrary time window or a staged subset. Evidence state is excluded
# because the manifests and stamps are generated from the candidate itself.

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -euo pipefail
fi

VALIDATION_EVIDENCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test-domain-risk.sh
source "$VALIDATION_EVIDENCE_DIR/test-domain-risk.sh"

validation_paths() {
  local mode="${1:-worktree}"
  local tracked=""
  local untracked=""

  # `--no-renames` is load-bearing, not a style choice. With rename detection on,
  # git pairs a deleted path with a similar added one and `--name-only` prints
  # only the destination, so the *deletion* silently drops out of the manifest
  # and is left unbound — restoring or altering that file would not change the
  # fingerprint. A real case: deleting `quickDoneIcon.imageset/Contents.json`
  # while adding `feedback_entry_2.imageset/Contents.json` paired at 55%
  # similarity and cost the manifest one path.
  case "$mode" in
    worktree)
      tracked=$(git diff --name-only --no-renames --diff-filter=ACMRD HEAD 2>/dev/null || true)
      untracked=$(git ls-files --others --exclude-standard 2>/dev/null || true)
      ;;
    staged)
      tracked=$(git diff --cached --name-only --no-renames --diff-filter=ACMRD 2>/dev/null || true)
      ;;
    *)
      echo "Unknown validation mode: $mode" >&2
      return 2
      ;;
  esac

  printf '%s\n%s\n' "$tracked" "$untracked" |
    sed '/^$/d' |
    grep -Ev '^\.claude/hooks/state/' |
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

validation_manifest_matches_staged() {
  local manifest="$1"
  local temporary=""

  [ -f "$manifest" ] || return 1
  temporary=$(mktemp)
  write_validation_manifest "$temporary" staged
  cmp -s "$manifest" "$temporary"
  local result=$?
  rm -f "$temporary"
  return "$result"
}

validation_stamp_has_field_value() {
  local stamp="$1"
  local key="$2"
  local value_pattern="$3"

  [ -f "$stamp" ] || return 1
  grep -qE "^[[:space:]]*${key}:[[:space:]]*${value_pattern}[[:space:]]*$" "$stamp"
}

validation_stamp_has_pass_result() {
  validation_stamp_has_field_value "$1" result PASS
}

test_execution_stamp_has_success_contract() {
  local stamp="$1"

  validation_stamp_has_pass_result "$stamp" &&
    validation_stamp_has_field_value "$stamp" exit_code 0
}

test_execution_stamp_has_domain_contract() {
  local stamp="$1"
  local expected_domain="${2:-low}"
  local actual_domain=""
  local actual_rank=0
  local expected_rank=0

  actual_domain=$(sed -n 's/^[[:space:]]*domain_risk:[[:space:]]*//p' "$stamp" 2>/dev/null | head -1)
  actual_rank=$(test_domain_risk_rank "$actual_domain" 2>/dev/null || echo -1)
  expected_rank=$(test_domain_risk_rank "$expected_domain" 2>/dev/null || echo 99)

  test_execution_stamp_has_success_contract "$stamp" &&
    validation_stamp_has_field_value "$stamp" domain_risk '(low|medium|high|blocker)' &&
    [ "$actual_rank" -ge "$expected_rank" ] &&
    validation_stamp_has_field_value "$stamp" mode '(run|verify)' &&
    validation_stamp_has_field_value "$stamp" source_fingerprint '[[:xdigit:]]{64}'
}

# High and blocker tiers must name a result bundle. Documenting
# that `verify` needs a readable artifact was not enough: the schema allowed
# `xcresult: n/a`, so a tester could pass every gate while the counts existed
# only in a message. `n/a` stays legal below high, where a run may legitimately
# be a native check without a bundle.
test_execution_stamp_has_xcresult_contract() {
  local stamp="$1"
  local expected_domain="${2:-low}"
  local xcresult=""

  case "$expected_domain" in
    high|blocker) ;;
    *) return 0 ;;
  esac

  # Trailing whitespace is stripped as well as leading. This is load-bearing for
  # a *valid* path: `…/run.xcresult ` would otherwise fail the shape check below
  # and a good stamp would be wrongly rejected. It is no longer what stops
  # `n/a ` — the shape check rejects that first — though it was, before the
  # shape check existed.
  xcresult=$(sed -n 's/^[[:space:]]*xcresult:[[:space:]]*//p' "$stamp" 2>/dev/null |
    head -1 |
    sed 's/[[:space:]]*$//')
  [ -n "$xcresult" ] || return 1
  [ "$xcresult" != "n/a" ] || return 1
  # Shape, not existence: `xcresult: yes` otherwise satisfies "named a bundle".
  case "$xcresult" in *.xcresult) ;; *) return 1 ;; esac
}

test_execution_stamp_has_required_fields() {
  local stamp="$1"
  local expected_domain="${2:-low}"

  test_execution_stamp_has_domain_contract "$stamp" "$expected_domain" &&
    test_execution_stamp_has_xcresult_contract "$stamp" "$expected_domain" &&
    validation_stamp_has_field_value "$stamp" verified_by tester-subagent
}

validation_stamp_matches_manifest() {
  local stamp="$1"
  local manifest="$2"
  local fingerprint=""

  [ -f "$stamp" ] || return 1
  [ -f "$manifest" ] || return 1
  validation_stamp_has_pass_result "$stamp" || return 1
  fingerprint=$(validation_manifest_fingerprint "$manifest")
  validation_stamp_has_field_value "$stamp" source_fingerprint "$fingerprint"
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
        validation_manifest_matches_staged "$2"
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
