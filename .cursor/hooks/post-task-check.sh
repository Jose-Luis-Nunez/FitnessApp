#!/bin/bash
# Stop Hook Orchestrator: runs all checks when the agent completes a task.
#
# Checks (each in its own script under checks/):
#   1. code-validation.sh     — Validation stamp fresh for Swift changes? (grind loop)
#   2. architecture-sync.sh   — architecture-documentation.md updated for structural changes?
#   3. test-execution.sh      — Tests run when test files changed?
#   4. test-coverage.sh       — New ViewModel/Service has corresponding tests?
#   5. enforcement-audit.sh   — Suggest audit for 5+ Swift file changes?
#   6. agent-infrastructure.sh — Agent-infra stamp fresh for .cursor/ changes?

set -euo pipefail

INPUT=$(cat)

STATUS=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null || echo "")
CONTENT=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('content',''))" 2>/dev/null || echo "")

if [ "$STATUS" != "completed" ]; then
  echo '{}'
  exit 0
fi

HAS_QUESTION=$(echo "$CONTENT" | grep -ciE '\?\s*$|soll ich|shall I|should I|do you want|möchtest du|willst du' || true)
if [ "$HAS_QUESTION" -gt 0 ]; then
  echo '{}'
  exit 0
fi

# --- Shared state ---

export STATE_DIR=".cursor/hooks/state"
export SCRATCHPAD="$STATE_DIR/scratchpad.json"
export MAX_GRIND_ITERATIONS=3
export CONTENT

mkdir -p "$STATE_DIR"

# Read scratchpad
if [ -f "$SCRATCHPAD" ]; then
  export SP_STATUS=$(python3 -c "import sys,json; print(json.load(open('$SCRATCHPAD')).get('status','pending'))" 2>/dev/null || echo "pending")
  export SP_ITERATION=$(python3 -c "import sys,json; print(json.load(open('$SCRATCHPAD')).get('iteration',0))" 2>/dev/null || echo "0")
  export SP_DIFF_HASH=$(python3 -c "import sys,json; print(json.load(open('$SCRATCHPAD')).get('diff_hash',''))" 2>/dev/null || echo "")
else
  export SP_STATUS="pending"
  export SP_ITERATION=0
  export SP_DIFF_HASH=""
fi

# Detect changed Swift files (shared across checks)
changed_swift=$(git diff --name-only HEAD 2>/dev/null | grep '\.swift$' || true)
new_swift=$(git ls-files --others --exclude-standard 2>/dev/null | grep '\.swift$' || true)
export all_swift=$(printf '%s\n%s' "$changed_swift" "$new_swift" | grep -v '^$' || true)

# --- Run checks ---

CHECKS_DIR="$(dirname "$0")/checks"
all_reasons=""

for check in \
  "$CHECKS_DIR/code-validation.sh" \
  "$CHECKS_DIR/architecture-sync.sh" \
  "$CHECKS_DIR/test-execution.sh" \
  "$CHECKS_DIR/test-coverage.sh" \
  "$CHECKS_DIR/enforcement-audit.sh" \
  "$CHECKS_DIR/agent-infrastructure.sh"; do

  if [ -f "$check" ]; then
    result=$(bash "$check" 2>/dev/null || true)
    if [ -n "$result" ]; then
      all_reasons="${all_reasons} ${result}"
    fi
  fi
done

# --- Output ---

if [ -n "$all_reasons" ]; then
  ESCAPED=$(echo "$all_reasons" | sed 's/"/\\"/g' | tr '\n' ' ')
  echo "{\"followup_message\": \"${ESCAPED}\"}"
else
  echo '{}'
fi
