#!/bin/bash
# Post-task hook: check if architecture.md needs updating after feature changes.
# Returns followup_message JSON to instruct the agent to fix missing docs sync.

set -euo pipefail

INPUT=$(cat)

STATUS=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null || echo "")
LOOP=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('loop_count',0))" 2>/dev/null || echo "0")

MAX_ITERATIONS=2

if [ "$STATUS" != "completed" ] || [ "$LOOP" -ge "$MAX_ITERATIONS" ]; then
  echo '{}'
  exit 0
fi

ARCH_FILE=".cursor/references/architecture.md"

new_feature_files=$(git diff --name-only --diff-filter=A HEAD 2>/dev/null | grep '^FitnessApp/Features/' || true)
new_appstyle=$(git diff --name-only HEAD 2>/dev/null | grep 'AppStyle.swift' || true)
new_navigation=$(git diff HEAD -- FitnessApp/FitnessAppApp.swift 2>/dev/null | grep '+.*case ' || true)
new_shared=$(git diff --name-only --diff-filter=A HEAD 2>/dev/null | grep '^FitnessApp/Shared/' || true)

arch_changed=$(git diff --name-only HEAD 2>/dev/null | grep "$ARCH_FILE" || true)

needs_sync=false
reasons=""

if [ -n "$new_feature_files" ] && [ -z "$arch_changed" ]; then
  needs_sync=true
  reasons="New feature files were added but architecture.md was not updated."
fi

if [ -n "$new_navigation" ] && [ -z "$arch_changed" ]; then
  needs_sync=true
  reasons="$reasons NavigationDestination cases changed but architecture.md was not updated."
fi

if [ -n "$new_appstyle" ] && [ -z "$arch_changed" ]; then
  needs_sync=true
  reasons="$reasons AppStyle.swift was modified but architecture.md was not updated."
fi

if [ -n "$new_shared" ] && [ -z "$arch_changed" ]; then
  needs_sync=true
  reasons="$reasons New shared components were added but architecture.md was not updated."
fi

if [ "$needs_sync" = true ]; then
  ESCAPED_REASONS=$(echo "$reasons" | sed 's/"/\\"/g' | tr '\n' ' ')
  echo "{\"followup_message\": \"[Docs Sync Required] ${ESCAPED_REASONS} Please update .cursor/references/architecture.md now to reflect these changes. Check the docs-sync rule for the trigger map.\"}"
else
  echo '{}'
fi
