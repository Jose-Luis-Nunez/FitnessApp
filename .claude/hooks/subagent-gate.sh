#!/bin/bash
# Kill-switch: when this sentinel exists, all SubagentStop gates are disabled.
# Both canonical and generated adapters use the canonical .claude state.
CANONICAL_STATE_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)/.claude/hooks/state"
# Re-enable by deleting .claude/hooks/state/checks-disabled.
if [ -f "$CANONICAL_STATE_DIR/checks-disabled" ]; then
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
  local manifest="$STATE_DIR/agent-infrastructure.manifest.tsv"
  local fingerprint=""
  source ".claude/hooks/lib/agent-infrastructure-evidence.sh"
  if ! agent_infrastructure_manifest_matches_worktree "$manifest"; then
    emit_block "[verifier] Gate failed: infrastructure manifest is missing or does not match the complete working-tree candidate. Write .claude/hooks/state/agent-infrastructure.manifest.tsv from working-tree contents with agent-infrastructure-evidence.sh."
  fi
  fingerprint=$(agent_infrastructure_manifest_fingerprint "$manifest")
  local checklist_fields=(
    reference_integrity
    overview_sync
    description_consistency
    handoff_links
    hook_alignment
    name_consistency
  )

  if [ ! -f "$stamp" ]; then
    emit_block "[verifier] Gate failed: stamp file missing. Write the agent-infrastructure stamp with result, verified_by, exact source_fingerprint, and all six checklist fields."
  fi

  if ! validation_stamp_has_pass_result "$stamp" ||
     ! validation_stamp_has_field_value "$stamp" verified_by verifier-subagent ||
     ! validation_stamp_has_field_value "$stamp" source_fingerprint "$fingerprint"; then
    emit_block "[verifier] Gate failed: stamp must contain exact result, verified_by, and source_fingerprint fields."
  fi

  for field in "${checklist_fields[@]}"; do
    if ! validation_stamp_has_field_value "$stamp" "$field" PASS; then
      emit_block "[verifier] Gate failed: stamp is missing exact field '$field: PASS'. Re-read .claude/agents/verifier.md and write a complete PASS stamp with all six checklist results."
    fi
  done
}

gate_reviewer() {
  local stamp="$STATE_DIR/code-changes.stamp.md"
  local manifest="$STATE_DIR/code-changes.manifest.tsv"
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

  source ".claude/hooks/lib/validation-evidence.sh"
  if ! validation_stamp_has_field_value "$stamp" verified_by reviewer-subagent ||
     ! validation_stamp_has_field_value "$stamp" risk '(green|yellow|red)'; then
    emit_block "[reviewer] Gate failed: stamp must contain exact verified_by: reviewer-subagent and risk fields."
  fi

  if ! validation_manifest_matches_worktree "$manifest" ||
     ! validation_stamp_matches_manifest "$stamp" "$manifest"; then
    emit_block "[reviewer] Gate failed: validation evidence does not match the complete working-tree candidate."
  fi
}

gate_tester() {
  local stamp="$STATE_DIR/test-execution.stamp.md"
  local manifest="$STATE_DIR/test-execution.manifest.tsv"
  local domain_risk=""

  if [ ! -f "$stamp" ]; then
    emit_block "[tester] Gate failed: test-execution stamp missing. Run xcodebuild test and write results to .claude/hooks/state/test-execution.stamp.md."
  fi

  source ".claude/hooks/lib/validation-evidence.sh"
  source ".claude/hooks/lib/test-domain-risk.sh"
  domain_risk=$(test_domain_changed_paths worktree | classify_test_domain_paths)
  if ! test_execution_stamp_has_required_fields "$stamp" "$domain_risk"; then
    emit_block "[tester] Gate failed: stamp must contain exact result: PASS, exit_code: 0, domain_risk: $domain_risk, verified_by: tester-subagent, mode: run|verify, and source_fingerprint fields."
  fi

  if ! validation_manifest_matches_worktree "$manifest" ||
     ! validation_stamp_matches_manifest "$stamp" "$manifest"; then
    emit_block "[tester] Gate failed: test evidence does not match the complete working-tree candidate."
  fi
}

case "$ROLE" in
  verifier) gate_verifier ;;
  reviewer) gate_reviewer ;;
  tester)   gate_tester ;;
esac

exit 0
