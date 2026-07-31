#!/bin/bash
# Generate or verify Codex runtime adapters from canonical .claude sources.

set -euo pipefail

MODE="${1:---check}"
if [ "$MODE" != "--check" ] && [ "$MODE" != "--write" ]; then
  echo "Usage: scripts/sync-agent-runtime.sh [--check|--write]" >&2
  exit 2
fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 1
cd "$REPO_ROOT"

COMMON_SKILLS=(
  create-feature
  debugging-ui-tests
  deep-research
  reviewing-agent-effectiveness
  reviewing-agent-infrastructure
  reviewing-code-changes
  reviewing-test-quality
  updating-ui-tests
  writing-ui-tests
)

ROLE_NAMES=(reviewer tester verifier)
HOOK_FILES=(post-task-check.sh subagent-gate.sh)

copy_or_compare() {
  local source="$1"
  local destination="$2"

  if [ "$MODE" = "--write" ]; then
    mkdir -p "$(dirname "$destination")"
    cp "$source" "$destination"
  elif ! cmp -s "$source" "$destination"; then
    echo "DRIFT: $destination differs from $source" >&2
    return 1
  fi
}

result=0

for skill in "${COMMON_SKILLS[@]}"; do
  copy_or_compare \
    ".claude/skills/$skill/SKILL.md" \
    ".agents/skills/$skill/SKILL.md" || result=1
done

for file in "${HOOK_FILES[@]}"; do
  copy_or_compare ".claude/hooks/$file" ".codex/hooks/$file" || result=1
done

for directory in checks lib tests; do
  [ -d ".claude/hooks/$directory" ] || continue
  while IFS= read -r source; do
    relative="${source#.claude/hooks/}"
    copy_or_compare "$source" ".codex/hooks/$relative" || result=1
  done <<< "$(find ".claude/hooks/$directory" -type f | sort)"
done

while IFS= read -r destination; do
  relative="${destination#.codex/hooks/}"
  if [ ! -f ".claude/hooks/$relative" ]; then
    if [ "$MODE" = "--write" ]; then
      rm "$destination"
    else
      echo "DRIFT: stale Codex hook adapter $destination has no canonical source" >&2
      result=1
    fi
  fi
done <<< "$(find .codex/hooks/checks .codex/hooks/lib .codex/hooks/tests -type f 2>/dev/null | sort)"

for role in "${ROLE_NAMES[@]}"; do
  if [ "$MODE" = "--write" ]; then
    scripts/generate-codex-agent.py \
      ".claude/agents/$role.md" \
      ".codex/agents/$role.toml"
  else
    temporary=$(mktemp)
    scripts/generate-codex-agent.py ".claude/agents/$role.md" "$temporary"
    if ! cmp -s "$temporary" ".codex/agents/$role.toml"; then
      echo "DRIFT: .codex/agents/$role.toml is not generated from .claude/agents/$role.md" >&2
      result=1
    fi
    rm -f "$temporary"
  fi
done

exit "$result"
