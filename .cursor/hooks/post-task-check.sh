#!/bin/bash
# Grind Loop: enforces post-change validation, docs sync, and test execution.
#
# Uses a scratchpad file (.cursor/hooks/state/scratchpad.json) to track
# iteration count across stop events. The agent cannot "finish" until
# validation has run or the iteration cap is hit.
#
# Checks:
#   1. Post-change validation (validation-stamp.md) for 2+ Swift files
#   2. architecture.md freshness for structural changes
#   3. Test execution proof (test-stamp.md) when test files changed

set -euo pipefail

INPUT=$(cat)

STATUS=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null || echo "")
LOOP=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('loop_count',0))" 2>/dev/null || echo "0")
CONTENT=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('content',''))" 2>/dev/null || echo "")

if [ "$STATUS" != "completed" ]; then
  echo '{}'
  exit 0
fi

# Don't interrupt when the agent is asking the user a question
HAS_QUESTION=$(echo "$CONTENT" | grep -ciE '\?\s*$|soll ich|shall I|should I|do you want|möchtest du|willst du' || true)
if [ "$HAS_QUESTION" -gt 0 ]; then
  echo '{}'
  exit 0
fi

# --- State management ---

STATE_DIR=".cursor/hooks/state"
SCRATCHPAD="$STATE_DIR/scratchpad.json"
REPORT_FILE="$STATE_DIR/validation-stamp.md"
MAX_GRIND_ITERATIONS=3

mkdir -p "$STATE_DIR"

# Read current scratchpad state
if [ -f "$SCRATCHPAD" ]; then
  SP_STATUS=$(python3 -c "import sys,json; print(json.load(open('$SCRATCHPAD')).get('status','pending'))" 2>/dev/null || echo "pending")
  SP_ITERATION=$(python3 -c "import sys,json; print(json.load(open('$SCRATCHPAD')).get('iteration',0))" 2>/dev/null || echo "0")
  SP_DIFF_HASH=$(python3 -c "import sys,json; print(json.load(open('$SCRATCHPAD')).get('diff_hash',''))" 2>/dev/null || echo "")
else
  SP_STATUS="pending"
  SP_ITERATION=0
  SP_DIFF_HASH=""
fi

# --- Check 1: Swift files changed? ---

changed_swift=$(git diff --name-only HEAD 2>/dev/null | grep '\.swift$' || true)
new_swift=$(git ls-files --others --exclude-standard 2>/dev/null | grep '\.swift$' || true)
all_swift=$(printf '%s\n%s' "$changed_swift" "$new_swift" | grep -v '^$' || true)

validation_reasons=""

if [ -n "$all_swift" ]; then
  swift_count=$(echo "$all_swift" | grep -c '\.swift$' || echo "0")
  DIFF_HASH=$(echo "$all_swift" | sort | shasum -a 256 | cut -d' ' -f1)

  # If diff changed since last scratchpad entry, reset iteration
  if [ "$DIFF_HASH" != "$SP_DIFF_HASH" ]; then
    SP_ITERATION=0
    SP_STATUS="pending"
  fi

  # Already marked DONE for this diff? Skip.
  if [ "$SP_STATUS" = "done" ]; then
    :
  elif [ "$swift_count" -lt 1 ]; then
    :
  else
    # Check for validation: artifact file OR markers in agent output
    HAS_ARTIFACT=false
    if [ -f "$REPORT_FILE" ]; then
      # Report exists — check if it's recent (< 10 min)
      REPORT_AGE=$(python3 -c "
import os, time
try:
    age = time.time() - os.path.getmtime('$REPORT_FILE')
    print('fresh' if age < 600 else 'stale')
except: print('stale')
" 2>/dev/null || echo "stale")
      if [ "$REPORT_AGE" = "fresh" ]; then
        HAS_ARTIFACT=true
      fi
    fi

    RAN_VALIDATION=$(echo "$CONTENT" | grep -ciE 'Post-Change Validation Report|post-change-validator|Validation Report' || true)

    if [ "$HAS_ARTIFACT" = true ] || [ "$RAN_VALIDATION" -gt 0 ]; then
      # Validation done — mark as complete
      python3 -c "
import json
data = {'status': 'done', 'iteration': $SP_ITERATION, 'diff_hash': '$DIFF_HASH'}
json.dump(data, open('$SCRATCHPAD', 'w'), indent=2)
" 2>/dev/null
    elif [ "$SP_ITERATION" -ge "$MAX_GRIND_ITERATIONS" ]; then
      # Cap reached — let the agent go, but note it
      python3 -c "
import json
data = {'status': 'cap_reached', 'iteration': $SP_ITERATION, 'diff_hash': '$DIFF_HASH'}
json.dump(data, open('$SCRATCHPAD', 'w'), indent=2)
" 2>/dev/null
    else
      # Increment iteration and send back
      NEW_ITER=$((SP_ITERATION + 1))
      python3 -c "
import json
data = {'status': 'validation_pending', 'iteration': $NEW_ITER, 'diff_hash': '$DIFF_HASH'}
json.dump(data, open('$SCRATCHPAD', 'w'), indent=2)
" 2>/dev/null

      file_list=$(echo "$all_swift" | head -15 | tr '\n' ', ' | sed 's/,$//')
      validation_reasons="[Grind Loop — Iteration ${NEW_ITER}/${MAX_GRIND_ITERATIONS}] ${swift_count} Swift files changed but no validation found. Run code-change validation NOW. Either: (1) launch the post-change-validator subagent, or (2) follow the reviewing-code-changes skill checklist manually. Write results to .cursor/hooks/state/validation-stamp.md. Changed files: ${file_list}."
    fi
  fi
fi

# --- Check 2: Does architecture.md need updating? ---

docs_reasons=""
ARCH_FILE=".cursor/references/architecture.md"
arch_changed=$(git diff --name-only HEAD 2>/dev/null | grep "$ARCH_FILE" || true)

new_feature_files=$(git diff --name-only --diff-filter=A HEAD 2>/dev/null | grep '^FitnessApp/Features/' || true)
new_appstyle=$(git diff --name-only HEAD 2>/dev/null | grep 'AppStyle.swift' || true)
new_navigation=$(git diff HEAD -- FitnessApp/FitnessAppApp.swift 2>/dev/null | grep '^+' | grep 'case [a-z]' | grep -v 'case \.' || true)
new_shared=$(git diff --name-only --diff-filter=A HEAD 2>/dev/null | grep '^FitnessApp/Shared/' || true)
new_usecases=$(git diff --name-only --diff-filter=A HEAD 2>/dev/null | grep 'UseCases/' || true)
new_services=$(git diff --name-only HEAD 2>/dev/null | grep -E 'Service\.swift|Container\.swift' || true)

if [ -n "$new_feature_files" ] && [ -z "$arch_changed" ]; then
  docs_reasons="${docs_reasons} New feature files added."
fi
if [ -n "$new_navigation" ] && [ -z "$arch_changed" ]; then
  docs_reasons="${docs_reasons} NavigationDestination cases changed."
fi
if [ -n "$new_appstyle" ] && [ -z "$arch_changed" ]; then
  docs_reasons="${docs_reasons} AppStyle.swift modified."
fi
if [ -n "$new_shared" ] && [ -z "$arch_changed" ]; then
  docs_reasons="${docs_reasons} New shared components added."
fi
if [ -n "$new_usecases" ] && [ -z "$arch_changed" ]; then
  docs_reasons="${docs_reasons} New Use Cases added."
fi
if [ -n "$new_services" ] && [ -z "$arch_changed" ]; then
  docs_reasons="${docs_reasons} Services or Container registrations changed."
fi

# --- Check 3: Test files changed but tests not run? (once per diff) ---

test_reasons=""
TEST_STAMP="$STATE_DIR/test-stamp.md"
TEST_HINT_SHOWN="$STATE_DIR/test-hint-hash.txt"

changed_tests=$(echo "$all_swift" | grep -iE 'Tests?/' || true)
changed_test_support=$(echo "$all_swift" | grep -i 'TestSupport' || true)
all_test_files="${changed_tests}${changed_test_support}"

if [ -n "$all_test_files" ]; then
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
      test_reasons="[Test Execution Required] Test files changed but no test run detected. Run the affected package tests using xcodebuild (see build-and-test rule). Write results to .cursor/hooks/state/test-stamp.md. Changed test files: ${test_file_list}."
      echo "$TEST_HASH" > "$TEST_HINT_SHOWN"
    fi
  fi
fi

# --- Check 4: New ViewModel/Service without corresponding tests? (once per diff) ---

test_coverage_reasons=""
COVERAGE_HINT_SHOWN="$STATE_DIR/coverage-hint-hash.txt"

new_vm_or_service=$(echo "$all_swift" | grep -v 'Tests' | grep -v 'TestSupport' | grep -iE 'ViewModel\.swift$|Service\.swift$' || true)

if [ -n "$new_vm_or_service" ]; then
  missing_tests=""
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    basename_no_ext=$(basename "$file" .swift)
    has_test=$(find . -path '*/Tests/*' -name "${basename_no_ext}Tests.swift" 2>/dev/null | head -1)
    if [ -z "$has_test" ]; then
      has_test=$(find ./FitnessAppTests -name "${basename_no_ext}Tests.swift" 2>/dev/null | head -1)
    fi
    if [ -z "$has_test" ]; then
      missing_tests="${missing_tests}  - ${file}\n"
    fi
  done <<< "$new_vm_or_service"

  if [ -n "$missing_tests" ]; then
    COVERAGE_HASH=$(echo "$new_vm_or_service" | sort | shasum -a 256 | cut -d' ' -f1)
    LAST_COVERAGE_HASH=""
    if [ -f "$COVERAGE_HINT_SHOWN" ]; then
      LAST_COVERAGE_HASH=$(cat "$COVERAGE_HINT_SHOWN" 2>/dev/null || echo "")
    fi
    if [ "$COVERAGE_HASH" != "$LAST_COVERAGE_HASH" ]; then
      test_coverage_reasons="[Tests Missing] New ViewModel/Service files without corresponding test files. Write unit tests for these: $(echo -e "$missing_tests" | tr '\n' ' '). Place tests in FitnessAppTests/ or the relevant Packages/*/Tests/ target."
      echo "$COVERAGE_HASH" > "$COVERAGE_HINT_SHOWN"
    fi
  fi
fi

# --- Check 5: Enforcement-Audit hint for large tasks (once per diff) ---

enforcement_hint=""
ENFORCEMENT_SHOWN="$STATE_DIR/enforcement-hint-hash.txt"

if [ -n "$all_swift" ]; then
  if [ "$swift_count" -ge 5 ]; then
    CURRENT_HASH=$(echo "$all_swift" | sort | shasum -a 256 | cut -d' ' -f1)
    LAST_SHOWN_HASH=""
    if [ -f "$ENFORCEMENT_SHOWN" ]; then
      LAST_SHOWN_HASH=$(cat "$ENFORCEMENT_SHOWN" 2>/dev/null || echo "")
    fi
    if [ "$CURRENT_HASH" != "$LAST_SHOWN_HASH" ]; then
      enforcement_hint="[Enforcement Audit Available] ${swift_count} Swift files changed. Consider running the reviewing-agent-effectiveness skill to verify all rules and hooks fired correctly."
      echo "$CURRENT_HASH" > "$ENFORCEMENT_SHOWN"
    fi
  fi
fi

# --- Output ---

all_reasons="${validation_reasons}"
if [ -n "$docs_reasons" ]; then
  all_reasons="${all_reasons} [Docs Sync Required]${docs_reasons} Update .cursor/references/architecture.md now. Check the docs-sync rule for the trigger map."
fi
if [ -n "$test_reasons" ]; then
  all_reasons="${all_reasons} ${test_reasons}"
fi
if [ -n "$test_coverage_reasons" ]; then
  all_reasons="${all_reasons} ${test_coverage_reasons}"
fi
if [ -n "$enforcement_hint" ]; then
  all_reasons="${all_reasons} ${enforcement_hint}"
fi

if [ -n "$all_reasons" ]; then
  ESCAPED=$(echo "$all_reasons" | sed 's/"/\\"/g' | tr '\n' ' ')
  echo "{\"followup_message\": \"${ESCAPED}\"}"
else
  echo '{}'
fi
