#!/bin/bash
# Executable agent infrastructure changed — does an independent verifier stamp
# match the exact current contents?
# Env: STATE_DIR, HOOKS_DIR, HAS_QUESTION

source "$HOOKS_DIR/lib/agent-infrastructure-evidence.sh"

all_cursor=$(agent_infrastructure_paths)

if [ -z "$all_cursor" ] || [ "$HAS_QUESTION" -gt 0 ]; then
  exit 0
fi

cursor_count=$(echo "$all_cursor" | wc -l | tr -d ' ')
manifest="$STATE_DIR/agent-infrastructure.manifest.tsv"
fingerprint=$(agent_infrastructure_manifest_fingerprint "$manifest" 2>/dev/null || true)
cursor_file_list=$(echo "$all_cursor" | head -10 | tr '\n' ', ' | sed 's/,$//')
stamp="$STATE_DIR/agent-infrastructure.stamp.md"

checklist_fields=(
  reference_integrity
  overview_sync
  description_consistency
  handoff_links
  hook_alignment
  name_consistency
)

if agent_infrastructure_manifest_matches_worktree "$manifest" && [ -f "$stamp" ]; then
  valid=false
  if validation_stamp_has_pass_result "$stamp" &&
     validation_stamp_has_field_value "$stamp" verified_by verifier-subagent &&
     validation_stamp_has_field_value "$stamp" source_fingerprint "$fingerprint"; then
    valid=true
    for field in "${checklist_fields[@]}"; do
      if ! validation_stamp_has_field_value "$stamp" "$field" PASS; then
        valid=false
        break
      fi
    done
  fi
  if [ "$valid" = true ]; then
    exit 0
  fi
fi

cat <<EOF
[Agent Infrastructure Validation Required] ${cursor_count} executable
agent-infrastructure files changed without an independent PASS stamp for their
exact current contents. Run reviewing-agent-infrastructure, publish its six-part
report, then spawn the fresh verifier. Changed files: ${cursor_file_list}.
Expected source_fingerprint: ${fingerprint}
EOF
