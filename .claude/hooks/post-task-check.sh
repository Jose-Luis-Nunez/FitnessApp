#!/bin/bash
# Kill-switch: when this sentinel exists, all Stop-hook checks are disabled.
# Both canonical and generated adapters use the canonical .claude state.
CANONICAL_STATE_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)/.claude/hooks/state"
# Re-enable by deleting .claude/hooks/state/checks-disabled.
if [ -f "$CANONICAL_STATE_DIR/checks-disabled" ]; then
  exit 0
fi
# Stop Hook Orchestrator (Claude Code): runs all checks when the agent stops.
#
# Claude Code Stop hook input (JSON via stdin):
#   { "session_id", "transcript_path", "cwd", "hook_event_name", "stop_hook_active" }
#
# We read the last assistant turn from the JSONL transcript to populate $CONTENT
# so the existing check scripts (which were written against Cursor's "content"
# field) keep working.
#
# Output:
#   - exit 0 with no stdout: success, no follow-up
#   - exit 2 with stderr text: Claude is sent back with that text as a blocker
#
# Checks (each in its own script under checks/):
#   1. code-validation.sh     — Content-bound validation for Swift changes.
#   2. architecture-sync.sh   — Stateless: architecture-documentation.md updated?
#   3. test-execution.sh      — Content-bound final test evidence for Swift changes.
#   4. test-coverage.sh       — Hint: new ViewModel/Service has corresponding tests?
#   5. agent-infrastructure.sh — Exact verifier evidence for runtime changes.
#   7. ui-state-sync.sh       — Hint: Int-counter + polling-loop anti-pattern in diff?
#   8. duplicate-state.sh     — Hint: new @State VM + existing UUID-keyed VM cache?
#   9. predicate-smell.sh     — Hint: SwiftData predicate anti-patterns.
#  10. adr-required.sh        — Hint: structural change without an ADR?
#
# Blocking checks require matching evidence; hint checks report likely gaps.

set -euo pipefail

INPUT=$(cat)

TRANSCRIPT_PATH=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('transcript_path',''))" 2>/dev/null || echo "")
STOP_HOOK_ACTIVE=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('stop_hook_active', False))" 2>/dev/null || echo "False")

# If Claude is already stopping due to a prior hook firing, don't re-fire — let it complete.
if [ "$STOP_HOOK_ACTIVE" = "True" ]; then
  exit 0
fi

# Extract last assistant turn(s) text from the transcript so checks can grep it.
CONTENT=""
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  CONTENT=$(python3 - "$TRANSCRIPT_PATH" <<'PY' || true
import json, sys
try:
    path = sys.argv[1]
    parts = []
    with open(path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except Exception:
                continue
            if rec.get('type') != 'assistant':
                continue
            msg = rec.get('message', {}) or {}
            content = msg.get('content')
            if isinstance(content, str):
                parts.append(content)
            elif isinstance(content, list):
                for block in content:
                    if isinstance(block, dict) and block.get('type') == 'text':
                        parts.append(block.get('text', ''))
    # Use only the tail (last ~2 assistant turns worth) to keep grep cheap.
    tail = parts[-3:] if parts else []
    sys.stdout.write('\n'.join(tail))
except Exception:
    pass
PY
)
fi

# --- Shared state ---

export STATE_DIR=".claude/hooks/state"
export CONTENT
export HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"

# Question detection: blocking completion checks pause while the agent asks the user.
# Hints still fire so the agent sees them when it resumes.
export HAS_QUESTION=$(echo "$CONTENT" | grep -ciE '\?\s*$|soll ich|shall I|should I|do you want|möchtest du|willst du' || true)

mkdir -p "$STATE_DIR"

# Detect changed Swift files (shared across checks)
changed_swift=$(git diff --name-only HEAD 2>/dev/null | grep '\.swift$' || true)
new_swift=$(git ls-files --others --exclude-standard 2>/dev/null | grep '\.swift$' || true)
export all_swift=$(printf '%s\n%s' "$changed_swift" "$new_swift" | grep -v '^$' || true)

# Risk and evidence are shared by the validation checks. Product documentation
# and agent-runtime files do not participate in this fingerprint.
source "$HOOKS_DIR/lib/change-risk.sh"
export CHANGE_RISK=$(classify_change_risk worktree)

# --- Run checks ---

CHECKS_DIR="$HOOKS_DIR/checks"
all_reasons=""

for check in \
  "$CHECKS_DIR/code-validation.sh" \
  "$CHECKS_DIR/architecture-sync.sh" \
  "$CHECKS_DIR/test-execution.sh" \
  "$CHECKS_DIR/test-coverage.sh" \
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
  # Exit 2 + stderr → Claude is sent back with this text as a blocker.
  printf '%s\n' "$all_reasons" >&2
  exit 2
fi

exit 0
