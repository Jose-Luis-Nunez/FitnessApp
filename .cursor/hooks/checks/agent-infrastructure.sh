#!/bin/bash
# Check 6: .cursor/ files changed — is agent-infrastructure stamp fresh?
# Pattern: Grind Loop (agent is sent back up to MAX_GRIND_ITERATIONS times)
# Env: CONTENT, STATE_DIR, HOOKS_DIR, MAX_GRIND_ITERATIONS, HAS_QUESTION

source "$HOOKS_DIR/lib/grind-loop.sh"

changed_cursor=$(git diff --name-only HEAD 2>/dev/null | grep '^\.cursor/' | grep -v '/state/' || true)
new_cursor=$(git ls-files --others --exclude-standard 2>/dev/null | grep '^\.cursor/' | grep -v '/state/' || true)
all_cursor=$(printf '%s\n%s' "$changed_cursor" "$new_cursor" | grep -v '^$' || true)

if [ -z "$all_cursor" ]; then
  exit 0
fi

cursor_count=$(echo "$all_cursor" | wc -l | tr -d ' ')
DIFF_HASH=$(echo "$all_cursor" | sort | shasum -a 256 | cut -d' ' -f1)
cursor_file_list=$(echo "$all_cursor" | head -10 | tr '\n' ', ' | sed 's/,$//')

run_grind_loop \
  "$STATE_DIR/agent-infrastructure.scratchpad.json" \
  "$STATE_DIR/agent-infrastructure.stamp.md" \
  "$DIFF_HASH" \
  "Agent Infrastructure Validation Report|agent-infrastructure\.stamp" \
  "${cursor_count} .cursor/ files changed but no agent-infrastructure validation found. Run the reviewing-agent-infrastructure skill checklist. Write results to .cursor/hooks/state/agent-infrastructure.stamp.md. Changed files: ${cursor_file_list}."
