#!/bin/bash
# Check 3: Swift files changed — is there one final, content-bound test result?
# Yellow/red evidence must be verified by the tester subagent. The tester may
# verify an existing matching result instead of running the same command again.
# Env: STATE_DIR, HOOKS_DIR, all_swift, HAS_QUESTION, CHANGE_RISK

source "$HOOKS_DIR/lib/validation-evidence.sh"
source "$HOOKS_DIR/lib/test-domain-risk.sh"

if [ -z "$all_swift" ]; then
  exit 0
fi

if [ "$HAS_QUESTION" -gt 0 ]; then
  exit 0
fi

stamp="$STATE_DIR/test-execution.stamp.md"
manifest="$STATE_DIR/test-execution.manifest.tsv"
file_list=$(echo "$all_swift" | head -10 | tr '\n' ', ' | sed 's/,$//')
test_domain_risk=$(test_domain_changed_paths worktree | classify_test_domain_paths)

if validation_manifest_matches_worktree "$manifest" &&
   validation_stamp_matches_manifest "$stamp" "$manifest" &&
   test_execution_stamp_has_domain_contract "$stamp" "$test_domain_risk"; then
  if [ "$CHANGE_RISK" = "green" ] ||
     test_execution_stamp_has_required_fields "$stamp" "$test_domain_risk"; then
    exit 0
  fi
fi

cat <<EOF
[Final Test Evidence Required — change risk: ${CHANGE_RISK}, test domain: ${test_domain_risk}] No successful test evidence matches the exact current contents.
Run the required affected tests once. If a matching final run already exists,
the tester must verify its command, exit code, result, and xcresult instead of
re-running it. Record:
  bash .claude/hooks/lib/validation-evidence.sh write .claude/hooks/state/test-execution.manifest.tsv
  bash .claude/hooks/lib/validation-evidence.sh fingerprint .claude/hooks/state/test-execution.manifest.tsv
Then write test-execution.stamp.md with result: PASS, domain_risk,
verified_by, command, test count, xcresult (a .xcresult path; required at high
and blocker, may be n/a below), and
source_fingerprint. Files: ${file_list}.
EOF
