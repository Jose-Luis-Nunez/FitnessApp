#!/bin/bash
# Exact-content fingerprint for executable agent-system changes.

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -euo pipefail
fi

agent_infrastructure_paths() {
  local tracked=""
  local untracked=""
  local include='^(\.claude/(rules/|skills/|hooks/(checks/|lib/|tests/|post-task-check\.sh|subagent-gate\.sh)|agents/|commands/|settings\.json$|references/agent-system-overview\.md$)|\.codex/(hooks\.json$|hooks/|agents/)|\.agents/skills/|\.githooks/|AGENTS\.md$|scripts/(sync-agent-runtime\.sh|generate-codex-agent\.py|test-affected-packages\.sh|install-hooks\.sh)$)'
  local exclude='/state/|^\.claude/plans/'

  tracked=$(git diff --name-only --diff-filter=ACMRD HEAD 2>/dev/null || true)
  untracked=$(git ls-files --others --exclude-standard 2>/dev/null || true)
  printf '%s\n%s\n' "$tracked" "$untracked" |
    sed '/^$/d' |
    grep -E "$include" |
    grep -Ev "$exclude" |
    sort -u || true
}

agent_infrastructure_fingerprint() {
  local path=""
  local hash=""

  while IFS= read -r path; do
    [ -z "$path" ] && continue
    if [ -f "$path" ]; then
      hash=$(shasum -a 256 "$path" | awk '{print $1}')
    else
      hash="DELETED"
    fi
    printf '%s\t%s\n' "$hash" "$path"
  done <<< "$(agent_infrastructure_paths)" |
    shasum -a 256 |
    awk '{print $1}'
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "${1:-fingerprint}" in
    paths) agent_infrastructure_paths ;;
    fingerprint) agent_infrastructure_fingerprint ;;
    *)
      echo "Usage: agent-infrastructure-evidence.sh [paths|fingerprint]" >&2
      exit 2
      ;;
  esac
fi
