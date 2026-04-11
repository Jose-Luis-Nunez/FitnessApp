#!/bin/bash
# Grind Loop: enforces post-change validation and docs sync.
#
# Uses a scratchpad file (.cursor/hooks/state/scratchpad.json) to track
# iteration count across stop events. The agent cannot "finish" until
# validation has run or the iteration cap is hit.
#
# Flow:
#   1. Agent says "done" → stop hook fires
#   2. Hook checks git diff for Swift changes
#   3. Hook checks for validation artifact (validation-stamp.md)
#   4. If missing: writes iteration to scratchpad, sends followup_message
#   5. If present or cap hit: writes DONE to scratchpad, returns {}

set -euo pipefail

INPUT=$(cat)

STATUS=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null || echo "")
LOOP=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('loop_count',0))" 2>/dev/null || echo "0")
CONTENT=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('content',''))" 2>/dev/null || echo "")

if [ "$STATUS" != "completed" ]; then
  echo '{}'
  exit 0
fi

# Don't interrupt when the agent is asking the user a question
HAS_QUESTION=$(echo "$CONTENT" | grep -ciE '\?\s*$|soll ich|shall I|should I|do you want|möchtest du|willst du' || true)
if [ "$HAS_QUESTION" -gt 0 ]; then
  echo '{}'
  exit 0
fi

# --- State management ---

STATE_DIR=".cursor/hooks/state"
SCRATCHPAD="$STATE_DIR/scratchpad.json"
REPORT_FILE="$STATE_DIR/validation-stamp.md"
MAX_GRIND_ITERATIONS=3

mkdir -p "$STATE_DIR"

# Read current scratchpad state
if [ -f "$SCRATCHPAD" ]; then
  SP_STATUS=$(python3 -c "import sys,json; print(json.load(open('$SCRATCHPAD')).get('status','pending'))" 2>/dev/null || echo "pending")
  SP_ITERATION=$(python3 -c "import sys,json; print(json.load(open('$SCRATCHPAD')).get('iteration',0))" 2>/dev/null || echo "0")
  SP_DIFF_HASH=$(python3 -c "import sys,json; print(json.load(open('$SCRATCHPAD')).get('diff_hash',''))" 2>/dev/null || echo "")
else
  SP_STATUS="pending"
  SP_ITERATION=0
  SP_DIFF_HASH=""
fi

# --- Check 1: Swift files changed? ---

changed_swift=$(git diff --name-only HEAD 2>/dev/null | grep '\.swift$' || true)
new_swift=$(git ls-files --others --exclude-standard 2>/dev/null | grep '\.swift$' || true)
all_swift="${changed_swift}${new_swift}"

validation_reasons=""

if [ -n "$all_swift" ]; then
  swift_count=$(echo "$all_swift" | grep -c '\.swift$' || echo "0")
  DIFF_HASH=$(echo "$all_swift" | sort | shasum -a 256 | cut -d' ' -f1)

  # If diff changed since last scratchpad entry, reset iteration
  if [ "$DIFF_HASH" != "$SP_DIFF_HASH" ]; then
    SP_ITERATION=0
    SP_STATUS="pending"
  fi

  # Already marked DONE for this diff? Skip.
  if [ "$SP_STATUS" = "done" ]; then
    :
  elif [ "$swift_count" -lt 2 ]; then
    # Trivial change, skip validation
    :
  else
    # Check for validation: artifact file OR markers in agent output
    HAS_ARTIFACT=false
    if [ -f "$REPORT_FILE" ]; then
      # Report exists — check if it's recent (< 10 min)
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

    RAN_VALIDATION=$(echo "$CONTENT" | grep -ciE 'Post-Change Validation Report|post-change-validator|Validation Report' || true)

    if [ "$HAS_ARTIFACT" = true ] || [ "$RAN_VALIDATION" -gt 0 ]; then
      # Validation done — mark as complete
      python3 -c "
import json
data = {'status': 'done', 'iteration': $SP_ITERATION, 'diff_hash': '$DIFF_HASH'}
json.dump(data, open('$SCRATCHPAD', 'w'), indent=2)
" 2>/dev/null
    elif [ "$SP_ITERATION" -ge "$MAX_GRIND_ITERATIONS" ]; then
      # Cap reached — let the agent go, but note it
      python3 -c "
import json
data = {'status': 'cap_reached', 'iteration': $SP_ITERATION, 'diff_hash': '$DIFF_HASH'}
json.dump(data, open('$SCRATCHPAD', 'w'), indent=2)
" 2>/dev/null
    else
      # Increment iteration and send back
      NEW_ITER=$((SP_ITERATION + 1))
      python3 -c "
import json
data = {'status': 'validation_pending', 'iteration': $NEW_ITER, 'diff_hash': '$DIFF_HASH'}
json.dump(data, open('$SCRATCHPAD', 'w'), indent=2)
" 2>/dev/null

      file_list=$(echo "$all_swift" | head -15 | tr '\n' ', ' | sed 's/,$//')
      validation_reasons="[Grind Loop — Iteration ${NEW_ITER}/${MAX_GRIND_ITERATIONS}] ${swift_count} Swift files changed but no validation found. Run post-change validation NOW. Either: (1) launch the post-change-validator subagent, or (2) follow the post-change-validation skill checklist manually. Write results to .cursor/hooks/state/validation-stamp.md. Changed files: ${file_list}."
    fi
  fi
fi

# --- Check 2: Does architecture.md need updating? ---

docs_reasons=""
ARCH_FILE=".cursor/references/architecture.md"
arch_changed=$(git diff --name-only HEAD 2>/dev/null | grep "$ARCH_FILE" || true)

new_feature_files=$(git diff --name-only --diff-filter=A HEAD 2>/dev/null | grep '^FitnessApp/Features/' || true)
new_appstyle=$(git diff --name-only HEAD 2>/dev/null | grep 'AppStyle.swift' || true)
new_navigation=$(git diff HEAD -- FitnessApp/FitnessAppApp.swift 2>/dev/null | grep '^+' | grep 'case [a-z]' | grep -v 'case \.' || true)
new_shared=$(git diff --name-only --diff-filter=A HEAD 2>/dev/null | grep '^FitnessApp/Shared/' || true)
new_usecases=$(git diff --name-only --diff-filter=A HEAD 2>/dev/null | grep 'UseCases/' || true)
new_services=$(git diff --name-only HEAD 2>/dev/null | grep -E 'Service\.swift|Container\.swift' || true)

if [ -n "$new_feature_files" ] && [ -z "$arch_changed" ]; then
  docs_reasons="${docs_reasons} New feature files added."
fi
if [ -n "$new_navigation" ] && [ -z "$arch_changed" ]; then
  docs_reasons="${docs_reasons} NavigationDestination cases changed."
fi
if [ -n "$new_appstyle" ] && [ -z "$arch_changed" ]; then
  docs_reasons="${docs_reasons} AppStyle.swift modified."
fi
if [ -n "$new_shared" ] && [ -z "$arch_changed" ]; then
  docs_reasons="${docs_reasons} New shared components added."
fi
if [ -n "$new_usecases" ] && [ -z "$arch_changed" ]; then
  docs_reasons="${docs_reasons} New Use Cases added."
fi
if [ -n "$new_services" ] && [ -z "$arch_changed" ]; then
  docs_reasons="${docs_reasons} Services or Container registrations changed."
fi

# --- Output ---

all_reasons="${validation_reasons}"
if [ -n "$docs_reasons" ]; then
  all_reasons="${all_reasons} [Docs Sync Required]${docs_reasons} Update .cursor/references/architecture.md now. Check the docs-sync rule for the trigger map."
fi

if [ -n "$all_reasons" ]; then
  ESCAPED=$(echo "$all_reasons" | sed 's/"/\\"/g' | tr '\n' ' ')
  echo "{\"followup_message\": \"${ESCAPED}\"}"
else
  echo '{}'
fi
