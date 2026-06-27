#!/bin/bash
# Kill-switch: when this sentinel exists, all SubagentStop gates are disabled.
# Re-enable by deleting it: rm .claude/hooks/state/checks-disabled
if [ -f "$(cd "$(dirname "$0")" && pwd)/state/checks-disabled" ]; then
  exit 0
fi
# SubagentStop hook (Claude Code): role-specific quality gates for subagents.
#
# Claude Code SubagentStop input (JSON via stdin):
#   { "session_id", "transcript_path", "cwd", "hook_event_name", "stop_hook_active" }
#
# We read the parent transcript to find the most recent Task tool call and
# extract:
#   ROLE     — from `subagent_type` (e.g. "reviewer", "tester", "verifier")
#   SUMMARY  — from the tool result (the subagent's final assistant message)
#
# Output:
#   - exit 0: gate passed
#   - exit 2 with stderr: gate failed, message is fed back to Claude

set -euo pipefail

INPUT=$(cat)

TRANSCRIPT_PATH=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('transcript_path',''))" 2>/dev/null || echo "")
STOP_HOOK_ACTIVE=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('stop_hook_active', False))" 2>/dev/null || echo "False")

if [ "$STOP_HOOK_ACTIVE" = "True" ]; then
  exit 0
fi

if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  exit 0
fi

# Extract ROLE (subagent_type) and SUMMARY (last tool_result text) from the
# most recent Task tool invocation in the transcript.
PARSED=$(python3 - "$TRANSCRIPT_PATH" <<'PY' || true
import json, sys
path = sys.argv[1]

last_task_id = None
last_role = ""
results = {}

try:
    with open(path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except Exception:
                continue
            msg = rec.get('message', {}) or {}
            content = msg.get('content')
            if not isinstance(content, list):
                continue
            for block in content:
                if not isinstance(block, dict):
                    continue
                btype = block.get('type')
                if btype == 'tool_use' and block.get('name') == 'Task':
                    last_task_id = block.get('id', '')
                    inp = block.get('input', {}) or {}
                    last_role = inp.get('subagent_type', '') or ''
                elif btype == 'tool_result':
                    tid = block.get('tool_use_id', '')
                    c = block.get('content')
                    if isinstance(c, list):
                        text = '\n'.join(
                            b.get('text', '') for b in c
                            if isinstance(b, dict) and b.get('type') == 'text'
                        )
                    elif isinstance(c, str):
                        text = c
                    else:
                        text = ''
                    if tid:
                        results[tid] = text
except Exception:
    pass

summary = results.get(last_task_id, '') if last_task_id else ''
print('ROLE=' + last_role)
print('---SUMMARY---')
print(summary)
PY
)

ROLE=$(echo "$PARSED" | sed -n 's/^ROLE=//p' | head -1)
SUMMARY=$(echo "$PARSED" | sed -n '/^---SUMMARY---$/,$p' | sed '1d')

if [ -z "$ROLE" ]; then
  exit 0
fi

STATE_DIR=".claude/hooks/state"
mkdir -p "$STATE_DIR"

emit_block() {
  printf '%s\n' "$1" >&2
  exit 2
}

gate_verifier() {
  local stamp="$STATE_DIR/agent-infrastructure.stamp.md"
  local required_fields=("result:" "verified_by:" "reference_integrity:" "overview_sync:" "description_consistency:" "handoff_links:" "hook_alignment:" "name_consistency:")

  if [ ! -f "$stamp" ]; then
    emit_block "[verifier] Gate failed: stamp file missing. Write the agent-infrastructure stamp to .claude/hooks/state/agent-infrastructure.stamp.md with all required fields: result, verified_by, reference_integrity, overview_sync, description_consistency, handoff_links, hook_alignment, name_consistency."
  fi

  for field in "${required_fields[@]}"; do
    if ! grep -q "$field" "$stamp"; then
      emit_block "[verifier] Gate failed: stamp is missing field '$field'. Re-read .claude/agents/verifier.md and write a complete stamp with all 8 required fields."
    fi
  done
}

gate_reviewer() {
  local stamp="$STATE_DIR/code-changes.stamp.md"
  local has_severity=0
  local has_no_issues=0
  local has_summary=0

  has_severity=$(echo "$SUMMARY" | grep -ciE '\*\*Bug\*\*|\*\*Nit\*\*|\*\*Pre-existing\*\*|Bug |Nit |Pre-existing ' || true)
  has_no_issues=$(echo "$SUMMARY" | grep -ciE 'no issues found|No issues found|No issues' || true)
  has_summary=$(echo "$SUMMARY" | grep -ciE 'Summary|summary' || true)

  if [ "$has_severity" -eq 0 ] && [ "$has_no_issues" -eq 0 ]; then
    emit_block "[reviewer] Gate failed: output must contain severity-tagged findings (Bug/Nit/Pre-existing) or explicitly state \"No issues found\". Re-read .claude/agents/reviewer.md and provide a complete review."
  fi

  if [ "$has_summary" -eq 0 ]; then
    emit_block "[reviewer] Gate failed: output must contain a Summary section. Re-read .claude/agents/reviewer.md and include a summary line."
  fi

  if [ ! -f "$stamp" ]; then
    emit_block "[reviewer] Gate failed: code-changes stamp missing. Write to .claude/hooks/state/code-changes.stamp.md with date, result, verified_by, files_inspected, findings fields."
  fi

  if ! grep -q "verified_by:" "$stamp"; then
    emit_block "[reviewer] Gate failed: stamp missing verified_by field. Re-write stamp with verified_by: reviewer-subagent."
  fi
}

gate_tester() {
  local stamp="$STATE_DIR/test-execution.stamp.md"

  if [ ! -f "$stamp" ]; then
    emit_block "[tester] Gate failed: test-execution stamp missing. Run xcodebuild test and write results to .claude/hooks/state/test-execution.stamp.md."
  fi

  local has_success=0
  has_success=$(grep -ciE 'all passed|TEST SUCCEEDED|Tests passed|Exit code: 0|exit code: 0' "$stamp" || true)

  if [ "$has_success" -eq 0 ]; then
    emit_block "[tester] Gate failed: test-execution stamp does not indicate success. Re-run failing tests and update .claude/hooks/state/test-execution.stamp.md."
  fi
}

case "$ROLE" in
  verifier) gate_verifier ;;
  reviewer) gate_reviewer ;;
  tester)   gate_tester ;;
esac

exit 0
