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

required_fields=(
  "result:[[:space:]]*PASS"
  "verified_by:[[:space:]]*verifier-subagent"
  "source_fingerprint:[[:space:]]*${fingerprint}"
  "reference_integrity:[[:space:]]*PASS"
  "overview_sync:[[:space:]]*PASS"
  "description_consistency:[[:space:]]*PASS"
  "handoff_links:[[:space:]]*PASS"
  "hook_alignment:[[:space:]]*PASS"
  "name_consistency:[[:space:]]*PASS"
)

if agent_infrastructure_manifest_matches_worktree "$manifest" && [ -f "$stamp" ]; then
  valid=true
  for field in "${required_fields[@]}"; do
    if ! grep -qE "$field" "$stamp"; then
      valid=false
      break
    fi
  done
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
