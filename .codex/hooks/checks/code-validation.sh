#!/bin/bash
# Check 1: Swift files changed — does validation match their exact contents?
# Green changes permit a main-agent self-review. Yellow/red require an
# independent reviewer stamp. No time window is involved.
# Env: STATE_DIR, HOOKS_DIR, all_swift, HAS_QUESTION, CHANGE_RISK

source "$HOOKS_DIR/lib/validation-evidence.sh"

if [ -z "$all_swift" ]; then
  exit 0
fi

swift_count=$(echo "$all_swift" | grep -c '\.swift$' || true)
swift_count=${swift_count:-0}
if [ "$swift_count" -lt 1 ]; then
  exit 0
fi

if [ "$HAS_QUESTION" -gt 0 ]; then
  exit 0
fi

stamp="$STATE_DIR/code-changes.stamp.md"
manifest="$STATE_DIR/code-changes.manifest.tsv"
file_list=$(echo "$all_swift" | head -15 | tr '\n' ', ' | sed 's/,$//')

if validation_manifest_matches_worktree "$manifest" &&
   validation_stamp_matches_manifest "$stamp" "$manifest" &&
   grep -q "risk:[[:space:]]*${CHANGE_RISK}" "$stamp"; then
  if [ "$CHANGE_RISK" = "green" ] ||
     grep -q 'verified_by:[[:space:]]*reviewer-subagent' "$stamp"; then
    exit 0
  fi
fi

if [ "$CHANGE_RISK" = "green" ]; then
  requirement="Run the lightweight green self-review and record content-bound evidence."
else
  requirement="Run the reviewing-code-changes skill and an independent reviewer for this ${CHANGE_RISK} change."
fi

cat <<EOF
[Validation Required — risk: ${CHANGE_RISK}] ${swift_count} Swift files do not have validation for their exact current contents. ${requirement}
Write the manifest with:
  bash .claude/hooks/lib/validation-evidence.sh write .claude/hooks/state/code-changes.manifest.tsv
Read its fingerprint with:
  bash .claude/hooks/lib/validation-evidence.sh fingerprint .claude/hooks/state/code-changes.manifest.tsv
Then write code-changes.stamp.md with result: PASS, risk: ${CHANGE_RISK},
verified_by, and source_fingerprint. Changed files: ${file_list}.
EOF
