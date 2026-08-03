#!/bin/bash
# Exact-content fingerprint for executable agent-system changes.

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -euo pipefail
fi

if ! declare -F validation_stamp_has_field_value >/dev/null; then
  # shellcheck source=validation-evidence.sh
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/validation-evidence.sh"
fi

agent_infrastructure_paths() {
  local mode="${1:-worktree}"
  local tracked=""
  local untracked=""
  local include='^(\.claude/(rules/|skills/|hooks/(checks/|lib/|tests/|post-task-check\.sh|subagent-gate\.sh)|agents/|commands/|settings\.json$|references/agent-system-overview\.md$)|\.codex/(hooks\.json$|hooks/|agents/)|\.agents/skills/|\.githooks/|AGENTS\.md$|scripts/(sync-agent-runtime\.sh|generate-codex-agent\.py|test-affected-packages\.sh|install-hooks\.sh)$)'
  local exclude='/state/|^\.claude/plans/'

  case "$mode" in
    worktree)
      tracked=$(git diff --name-only --diff-filter=ACMRD HEAD 2>/dev/null || true)
      untracked=$(git ls-files --others --exclude-standard 2>/dev/null || true)
      ;;
    staged)
      tracked=$(git diff --cached --name-only --diff-filter=ACMRD 2>/dev/null || true)
      ;;
    *)
      echo "Unknown infrastructure-evidence mode: $mode" >&2
      return 2
      ;;
  esac
  printf '%s\n%s\n' "$tracked" "$untracked" |
    sed '/^$/d' |
    grep -E "$include" |
    grep -Ev "$exclude" |
    sort -u || true
}

agent_infrastructure_hash_for_path() {
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

write_agent_infrastructure_manifest() {
  local output="$1"
  local mode="${2:-worktree}"
  local path=""
  local hash=""
  local temporary="${output}.tmp.$$"

  : > "$temporary"
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    hash=$(agent_infrastructure_hash_for_path "$mode" "$path")
    printf '%s\t%s\n' "$hash" "$path" >> "$temporary"
  done <<< "$(agent_infrastructure_paths "$mode")"

  sort -t $'\t' -k2,2 "$temporary" > "$output"
  rm -f "$temporary"
}

agent_infrastructure_manifest_fingerprint() {
  local manifest="$1"
  [ -f "$manifest" ] || return 1
  shasum -a 256 "$manifest" | awk '{print $1}'
}

agent_infrastructure_manifest_matches_worktree() {
  local manifest="$1"
  local temporary=""

  [ -f "$manifest" ] || return 1
  temporary=$(mktemp)
  write_agent_infrastructure_manifest "$temporary" worktree
  cmp -s "$manifest" "$temporary"
  local result=$?
  rm -f "$temporary"
  return "$result"
}

agent_infrastructure_manifest_matches_staged() {
  local manifest="$1"
  local temporary=""

  [ -f "$manifest" ] || return 1
  temporary=$(mktemp)
  write_agent_infrastructure_manifest "$temporary" staged
  cmp -s "$manifest" "$temporary"
  local result=$?
  rm -f "$temporary"
  return "$result"
}

agent_infrastructure_stamp_matches_manifest() {
  local stamp="$1"
  local manifest="$2"
  local fingerprint=""

  [ -f "$stamp" ] || return 1
  fingerprint=$(agent_infrastructure_manifest_fingerprint "$manifest") || return 1
  validation_stamp_has_pass_result "$stamp" &&
    validation_stamp_has_field_value "$stamp" source_fingerprint "$fingerprint"
}

agent_infrastructure_fingerprint() {
  local mode="${1:-worktree}"
  local path=""
  local hash=""

  while IFS= read -r path; do
    [ -z "$path" ] && continue
    hash=$(agent_infrastructure_hash_for_path "$mode" "$path")
    printf '%s\t%s\n' "$hash" "$path"
  done <<< "$(agent_infrastructure_paths "$mode")" |
    shasum -a 256 |
    awk '{print $1}'
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "${1:-fingerprint}" in
    paths) agent_infrastructure_paths "${2:-worktree}" ;;
    write)
      [ "$#" -ge 2 ] || { echo "Usage: agent-infrastructure-evidence.sh write <manifest> [worktree|staged]" >&2; exit 2; }
      write_agent_infrastructure_manifest "$2" "${3:-worktree}"
      ;;
    verify)
      [ "$#" -ge 2 ] || { echo "Usage: agent-infrastructure-evidence.sh verify <manifest> [worktree|staged]" >&2; exit 2; }
      if [ "${3:-worktree}" = "staged" ]; then
        agent_infrastructure_manifest_matches_staged "$2"
      else
        agent_infrastructure_manifest_matches_worktree "$2"
      fi
      ;;
    fingerprint)
      if [ "$#" -eq 2 ]; then
        agent_infrastructure_manifest_fingerprint "$2"
      else
        agent_infrastructure_fingerprint
      fi
      ;;
    stamp-matches)
      [ "$#" -eq 3 ] || { echo "Usage: agent-infrastructure-evidence.sh stamp-matches <stamp> <manifest>" >&2; exit 2; }
      agent_infrastructure_stamp_matches_manifest "$2" "$3"
      ;;
    *)
      echo "Usage: agent-infrastructure-evidence.sh [paths|fingerprint]" >&2
      exit 2
      ;;
  esac
fi
