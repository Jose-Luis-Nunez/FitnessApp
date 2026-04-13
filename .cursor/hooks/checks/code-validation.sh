#!/bin/bash
# Check 1: Swift files changed — is validation stamp fresh?
# Uses grind loop (up to MAX_GRIND_ITERATIONS retries).
# Env: CONTENT, STATE_DIR, all_swift, SCRATCHPAD, SP_STATUS, SP_ITERATION, SP_DIFF_HASH, MAX_GRIND_ITERATIONS

if [ -z "$all_swift" ]; then
  exit 0
fi

swift_count=$(echo "$all_swift" | grep -c '\.swift$' || echo "0")
DIFF_HASH=$(echo "$all_swift" | sort | shasum -a 256 | cut -d' ' -f1)
REPORT_FILE="$STATE_DIR/validation-stamp.md"

if [ "$DIFF_HASH" != "$SP_DIFF_HASH" ]; then
  SP_ITERATION=0
  SP_STATUS="pending"
fi

if [ "$SP_STATUS" = "done" ] || [ "$swift_count" -lt 1 ]; then
  exit 0
fi

HAS_ARTIFACT=false
if [ -f "$REPORT_FILE" ]; then
  REPORT_AGE=$(python3 -c "
import os, time
try:
    age = time.time() - os.path.getmtime('$REPORT_FILE')
    print('fresh' if age < 600 else 'stale')
except: print('stale')
" 2>/dev/null || echo "stale")
  if [ "$REPORT_AGE" = "fresh" ]; then
    HAS_ARTIFACT=true
  fi
fi

RAN_VALIDATION=$(echo "$CONTENT" | grep -ciE 'Post-Change Validation Report|Validation Report|Code Review Report' || true)

if [ "$HAS_ARTIFACT" = true ] || [ "$RAN_VALIDATION" -gt 0 ]; then
  python3 -c "
import json
data = {'status': 'done', 'iteration': $SP_ITERATION, 'diff_hash': '$DIFF_HASH'}
json.dump(data, open('$SCRATCHPAD', 'w'), indent=2)
" 2>/dev/null
elif [ "$SP_ITERATION" -ge "$MAX_GRIND_ITERATIONS" ]; then
  python3 -c "
import json
data = {'status': 'cap_reached', 'iteration': $SP_ITERATION, 'diff_hash': '$DIFF_HASH'}
json.dump(data, open('$SCRATCHPAD', 'w'), indent=2)
" 2>/dev/null
else
  NEW_ITER=$((SP_ITERATION + 1))
  python3 -c "
import json
data = {'status': 'validation_pending', 'iteration': $NEW_ITER, 'diff_hash': '$DIFF_HASH'}
json.dump(data, open('$SCRATCHPAD', 'w'), indent=2)
" 2>/dev/null

  file_list=$(echo "$all_swift" | head -15 | tr '\n' ', ' | sed 's/,$//')
  echo "[Grind Loop — Iteration ${NEW_ITER}/${MAX_GRIND_ITERATIONS}] ${swift_count} Swift files changed but no validation found. Run code-change validation NOW: follow the reviewing-code-changes skill checklist (.cursor/skills/reviewing-code-changes/SKILL.md). Write results to .cursor/hooks/state/validation-stamp.md. Changed files: ${file_list}."
fi
