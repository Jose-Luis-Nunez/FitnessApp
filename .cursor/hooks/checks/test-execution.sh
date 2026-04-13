#!/bin/bash
# Check 3: Test files changed — were tests actually run?
# Pattern: Grind Loop (agent is sent back up to MAX_GRIND_ITERATIONS times)
# Env: CONTENT, STATE_DIR, HOOKS_DIR, all_swift, MAX_GRIND_ITERATIONS, HAS_QUESTION

source "$HOOKS_DIR/lib/grind-loop.sh"

changed_tests=$(echo "$all_swift" | grep -iE 'Tests?/' || true)
changed_test_support=$(echo "$all_swift" | grep -i 'TestSupport' || true)
all_test_files=$(printf '%s\n%s' "$changed_tests" "$changed_test_support" | grep -v '^$' || true)

if [ -z "$all_test_files" ]; then
  exit 0
fi

DIFF_HASH=$(echo "$all_test_files" | sort | shasum -a 256 | cut -d' ' -f1)
test_file_list=$(echo "$all_test_files" | head -10 | tr '\n' ', ' | sed 's/,$//')

run_grind_loop \
  "$STATE_DIR/test-execution.scratchpad.json" \
  "$STATE_DIR/test-execution.stamp.md" \
  "$DIFF_HASH" \
  "TEST SUCCEEDED|Test Suite Passed|Tests passed|test-execution\.stamp" \
  "Test files changed but no test run detected. Run the affected package tests using xcodebuild (see build-and-test rule). Write results to .cursor/hooks/state/test-execution.stamp.md. Changed test files: ${test_file_list}."
