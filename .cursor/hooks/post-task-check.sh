#!/bin/bash
# Stop Hook Orchestrator: runs all checks when the agent completes a task.
#
# Checks (each in its own script under checks/):
#   1. code-validation.sh     — Grind loop: validation stamp fresh for Swift changes?
#   2. architecture-sync.sh   — Stateless: architecture-documentation.md updated?
#   3. test-execution.sh      — Grind loop: tests run when test files changed?
#   4. test-coverage.sh       — Hint: new ViewModel/Service has corresponding tests?
#   5. enforcement-audit.sh   — Hint: suggest audit for 5+ Swift file changes?
#   6. agent-infrastructure.sh — Grind loop: agent-infra stamp fresh for .cursor/ changes?
#   7. ui-state-sync.sh       — Hint: Int-counter + polling-loop anti-pattern in diff?
#   8. duplicate-state.sh     — Hint: new @State VM + existing UUID-keyed VM cache?
#   9. predicate-smell.sh     — Hint: SwiftData predicate anti-patterns (?., !., persistentModelID, @ModelActor)?
#  10. adr-required.sh        — Hint: structural change without an ADR?
#
# Two enforcement patterns:
#   Grind Loop — agent is sent back up to MAX_GRIND_ITERATIONS times (checks 1, 3, 6)
#   Hint       — one-time suggestion, no retry (checks 2, 4, 5, 7, 8, 9, 10)

set -euo pipefail

INPUT=$(cat)

STATUS=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null || echo "")
CONTENT=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('content',''))" 2>/dev/null || echo "")

if [ "$STATUS" != "completed" ]; then
  echo '{}'
  exit 0
fi

# --- Shared state ---

export STATE_DIR=".cursor/hooks/state"
export MAX_GRIND_ITERATIONS=3
export CONTENT
export HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"

# Question detection: grind-loop checks skip when agent is asking the user.
# Hints still fire so the agent sees them when it resumes.
export HAS_QUESTION=$(echo "$CONTENT" | grep -ciE '\?\s*$|soll ich|shall I|should I|do you want|möchtest du|willst du' || true)

mkdir -p "$STATE_DIR"

# Detect changed Swift files (shared across checks)
changed_swift=$(git diff --name-only HEAD 2>/dev/null | grep '\.swift$' || true)
new_swift=$(git ls-files --others --exclude-standard 2>/dev/null | grep '\.swift$' || true)
export all_swift=$(printf '%s\n%s' "$changed_swift" "$new_swift" | grep -v '^$' || true)

# --- Run checks ---

CHECKS_DIR="$HOOKS_DIR/checks"
all_reasons=""

for check in \
  "$CHECKS_DIR/code-validation.sh" \
  "$CHECKS_DIR/architecture-sync.sh" \
  "$CHECKS_DIR/test-execution.sh" \
  "$CHECKS_DIR/test-coverage.sh" \
  "$CHECKS_DIR/enforcement-audit.sh" \
  "$CHECKS_DIR/agent-infrastructure.sh" \
  "$CHECKS_DIR/ui-state-sync.sh" \
  "$CHECKS_DIR/duplicate-state.sh" \
  "$CHECKS_DIR/predicate-smell.sh" \
  "$CHECKS_DIR/adr-required.sh"; do

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
