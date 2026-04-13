#!/bin/bash
# subagentStop hook: role-specific quality gates for subagents.
#
# Parses [ROLE:name] from the task field and applies role-specific checks:
#   verifier — stamp exists + has 8 required fields
#   reviewer — output contains severity tags or "no issues" + summary
#   tester   — test-execution stamp exists + contains success marker
#
# Input (JSON via stdin): subagent_type, status, task, summary, loop_count, ...
# Output (JSON via stdout): { "followup_message": "..." } or {}

set -euo pipefail

INPUT=$(cat)

STATUS=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null || echo "")
TASK=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('task',''))" 2>/dev/null || echo "")
SUMMARY=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('summary',''))" 2>/dev/null || echo "")
LOOP_COUNT=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('loop_count',0))" 2>/dev/null || echo "0")

if [ "$STATUS" != "completed" ]; then
  echo '{}'
  exit 0
fi

ROLE=$(echo "$TASK" | grep -oE '\[ROLE:[a-z_]+\]' | head -1 | sed 's/\[ROLE://;s/\]//' || true)

if [ -z "$ROLE" ]; then
  echo '{}'
  exit 0
fi

STATE_DIR=".cursor/hooks/state"
mkdir -p "$STATE_DIR"

gate_verifier() {
  local stamp="$STATE_DIR/agent-infrastructure.stamp.md"
  local required_fields=("result:" "verified_by:" "reference_integrity:" "overview_sync:" "description_consistency:" "handoff_links:" "hook_alignment:" "name_consistency:")

  if [ ! -f "$stamp" ]; then
    echo '{"followup_message": "[ROLE:verifier] Gate failed: stamp file missing. Write the agent-infrastructure stamp to .cursor/hooks/state/agent-infrastructure.stamp.md with all required fields: result, verified_by, reference_integrity, overview_sync, description_consistency, handoff_links, hook_alignment, name_consistency."}'
    return
  fi

  for field in "${required_fields[@]}"; do
    if ! grep -q "$field" "$stamp"; then
      echo "{\"followup_message\": \"[ROLE:verifier] Gate failed: stamp is missing field '$field'. Re-read .cursor/agent-roles/verifier.md and write a complete stamp with all 8 required fields.\"}"
      return
    fi
  done

  echo '{}'
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
    echo '{"followup_message": "[ROLE:reviewer] Gate failed: output must contain severity-tagged findings (Bug/Nit/Pre-existing) or explicitly state \"No issues found\". Re-read .cursor/agent-roles/reviewer.md and provide a complete review."}'
    return
  fi

  if [ "$has_summary" -eq 0 ]; then
    echo '{"followup_message": "[ROLE:reviewer] Gate failed: output must contain a Summary section. Re-read .cursor/agent-roles/reviewer.md and include a summary line."}'
    return
  fi

  if [ ! -f "$stamp" ]; then
    echo '{"followup_message": "[ROLE:reviewer] Gate failed: code-changes stamp missing. Write to .cursor/hooks/state/code-changes.stamp.md with date, result, verified_by, files_inspected, findings fields."}'
    return
  fi

  if ! grep -q "verified_by:" "$stamp"; then
    echo '{"followup_message": "[ROLE:reviewer] Gate failed: stamp missing verified_by field. Re-write stamp with verified_by: reviewer-subagent."}'
    return
  fi

  echo '{}'
}

gate_tester() {
  local stamp="$STATE_DIR/test-execution.stamp.md"

  if [ ! -f "$stamp" ]; then
    echo '{"followup_message": "[ROLE:tester] Gate failed: test-execution stamp missing. Run xcodebuild test and write results to .cursor/hooks/state/test-execution.stamp.md."}'
    return
  fi

  local has_success=0
  has_success=$(grep -ciE 'all passed|TEST SUCCEEDED|Tests passed|Exit code: 0|exit code: 0' "$stamp" || true)

  if [ "$has_success" -eq 0 ]; then
    echo '{"followup_message": "[ROLE:tester] Gate failed: test-execution stamp does not indicate success. Re-run failing tests and update .cursor/hooks/state/test-execution.stamp.md."}'
    return
  fi

  echo '{}'
}

case "$ROLE" in
  verifier)  gate_verifier ;;
  reviewer)  gate_reviewer ;;
  tester)    gate_tester ;;
  *)         echo '{}' ;;
esac
