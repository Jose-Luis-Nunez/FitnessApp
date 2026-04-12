#!/bin/bash
# Check 6: .cursor/ files changed — is agent-infrastructure stamp fresh?
# Env: CONTENT, STATE_DIR

AGENT_STAMP="$STATE_DIR/agent-validation-stamp.md"
AGENT_HINT_FILE="$STATE_DIR/agent-infra-hint-hash.txt"

changed_cursor=$(git diff --name-only HEAD 2>/dev/null | grep '^\.cursor/' | grep -v '/state/' || true)
new_cursor=$(git ls-files --others --exclude-standard 2>/dev/null | grep '^\.cursor/' | grep -v '/state/' || true)
all_cursor=$(printf '%s\n%s' "$changed_cursor" "$new_cursor" | grep -v '^$' || true)

if [ -z "$all_cursor" ]; then
  exit 0
fi

cursor_count=$(echo "$all_cursor" | wc -l | tr -d ' ')

HAS_AGENT_STAMP=false
if [ -f "$AGENT_STAMP" ]; then
  AGENT_STAMP_AGE=$(python3 -c "
import os, time
try:
    age = time.time() - os.path.getmtime('$AGENT_STAMP')
    print('fresh' if age < 600 else 'stale')
except: print('stale')
" 2>/dev/null || echo "stale")
  if [ "$AGENT_STAMP_AGE" = "fresh" ]; then
    HAS_AGENT_STAMP=true
  fi
fi

RAN_AGENT_VALIDATION=$(echo "$CONTENT" | grep -ciE 'Agent Infrastructure Validation Report|agent-validation-stamp' || true)

if [ "$HAS_AGENT_STAMP" = false ] && [ "$RAN_AGENT_VALIDATION" -eq 0 ]; then
  AGENT_HASH=$(echo "$all_cursor" | sort | shasum -a 256 | cut -d' ' -f1)
  LAST_AGENT_HASH=""
  if [ -f "$AGENT_HINT_FILE" ]; then
    LAST_AGENT_HASH=$(cat "$AGENT_HINT_FILE" 2>/dev/null || echo "")
  fi
  if [ "$AGENT_HASH" != "$LAST_AGENT_HASH" ]; then
    cursor_file_list=$(echo "$all_cursor" | head -10 | tr '\n' ', ' | sed 's/,$//')
    echo "[Agent Infrastructure Validation Required] ${cursor_count} .cursor/ files changed but no agent-infrastructure validation found. Run the reviewing-agent-infrastructure skill checklist. Write results to .cursor/hooks/state/agent-validation-stamp.md. Changed files: ${cursor_file_list}."
    echo "$AGENT_HASH" > "$AGENT_HINT_FILE"
  fi
fi
