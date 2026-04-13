#!/bin/bash
# Check 1: Swift files changed — is validation stamp fresh?
# Pattern: Grind Loop (agent is sent back up to MAX_GRIND_ITERATIONS times)
# Env: CONTENT, STATE_DIR, HOOKS_DIR, all_swift, MAX_GRIND_ITERATIONS, HAS_QUESTION

source "$HOOKS_DIR/lib/grind-loop.sh"

if [ -z "$all_swift" ]; then
  exit 0
fi

swift_count=$(echo "$all_swift" | grep -c '\.swift$' || echo "0")
if [ "$swift_count" -lt 1 ]; then
  exit 0
fi

DIFF_HASH=$(echo "$all_swift" | sort | shasum -a 256 | cut -d' ' -f1)
file_list=$(echo "$all_swift" | head -15 | tr '\n' ', ' | sed 's/,$//')

run_grind_loop \
  "$STATE_DIR/code-changes.scratchpad.json" \
  "$STATE_DIR/code-changes.stamp.md" \
  "$DIFF_HASH" \
  "Post-Change Validation Report|Validation Report|Code Review Report" \
  "${swift_count} Swift files changed but no validation found. Run code-change validation NOW: follow the reviewing-code-changes skill checklist (.cursor/skills/reviewing-code-changes/SKILL.md). Write results to .cursor/hooks/state/code-changes.stamp.md. Changed files: ${file_list}."
