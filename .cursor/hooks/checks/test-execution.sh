#!/bin/bash
# Check 3: Test files changed — were tests actually run?
# Env: CONTENT, STATE_DIR, all_swift

TEST_STAMP="$STATE_DIR/test-stamp.md"
TEST_HINT_SHOWN="$STATE_DIR/test-hint-hash.txt"

changed_tests=$(echo "$all_swift" | grep -iE 'Tests?/' || true)
changed_test_support=$(echo "$all_swift" | grep -i 'TestSupport' || true)
all_test_files="${changed_tests}${changed_test_support}"

if [ -z "$all_test_files" ]; then
  exit 0
fi

HAS_TEST_ARTIFACT=false
if [ -f "$TEST_STAMP" ]; then
  TEST_AGE=$(python3 -c "
import os, time
try:
    age = time.time() - os.path.getmtime('$TEST_STAMP')
    print('fresh' if age < 900 else 'stale')
except: print('stale')
" 2>/dev/null || echo "stale")
  if [ "$TEST_AGE" = "fresh" ]; then
    HAS_TEST_ARTIFACT=true
  fi
fi

RAN_TESTS=$(echo "$CONTENT" | grep -ciE 'TEST SUCCEEDED|Test Suite Passed|Tests passed|test-stamp' || true)

if [ "$HAS_TEST_ARTIFACT" = false ] && [ "$RAN_TESTS" -eq 0 ]; then
  TEST_HASH=$(echo "$all_test_files" | sort | shasum -a 256 | cut -d' ' -f1)
  LAST_TEST_HASH=""
  if [ -f "$TEST_HINT_SHOWN" ]; then
    LAST_TEST_HASH=$(cat "$TEST_HINT_SHOWN" 2>/dev/null || echo "")
  fi
  if [ "$TEST_HASH" != "$LAST_TEST_HASH" ]; then
    test_file_list=$(echo "$all_test_files" | head -10 | tr '\n' ', ' | sed 's/,$//')
    echo "[Test Execution Required] Test files changed but no test run detected. Run the affected package tests using xcodebuild (see build-and-test rule). Write results to .cursor/hooks/state/test-stamp.md. Changed test files: ${test_file_list}."
    echo "$TEST_HASH" > "$TEST_HINT_SHOWN"
  fi
fi
