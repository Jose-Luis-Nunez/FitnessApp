#!/bin/bash
# Check 3: Swift files changed — is there one final, content-bound test result?
# Yellow/red evidence must be verified by the tester subagent. The tester may
# verify an existing matching result instead of running the same command again.
# Env: STATE_DIR, HOOKS_DIR, all_swift, HAS_QUESTION, CHANGE_RISK

source "$HOOKS_DIR/lib/validation-evidence.sh"

if [ -z "$all_swift" ]; then
  exit 0
fi

if [ "$HAS_QUESTION" -gt 0 ]; then
  exit 0
fi

stamp="$STATE_DIR/test-execution.stamp.md"
manifest="$STATE_DIR/test-execution.manifest.tsv"
file_list=$(echo "$all_swift" | head -10 | tr '\n' ', ' | sed 's/,$//')

if validation_manifest_matches_worktree "$manifest" &&
   validation_stamp_matches_manifest "$stamp" "$manifest"; then
  if [ "$CHANGE_RISK" = "green" ] ||
     grep -q 'verified_by:[[:space:]]*tester-subagent' "$stamp"; then
    exit 0
  fi
fi

cat <<EOF
[Final Test Evidence Required — risk: ${CHANGE_RISK}] No successful test evidence matches the exact current contents.
Run the required affected tests once. If a matching final run already exists,
the tester must verify its command, exit code, result, and xcresult instead of
re-running it. Record:
  bash .claude/hooks/lib/validation-evidence.sh write .claude/hooks/state/test-execution.manifest.tsv
  bash .claude/hooks/lib/validation-evidence.sh fingerprint .claude/hooks/state/test-execution.manifest.tsv
Then write test-execution.stamp.md with result: PASS, verified_by, command,
test count, xcresult (when available), and source_fingerprint. Files: ${file_list}.
EOF
