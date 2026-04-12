#!/bin/bash
# Check 4: New ViewModel/Service without corresponding test file?
# Env: STATE_DIR, all_swift

COVERAGE_HINT_SHOWN="$STATE_DIR/coverage-hint-hash.txt"

new_vm_or_service=$(echo "$all_swift" | grep -v 'Tests' | grep -v 'TestSupport' | grep -iE 'ViewModel\.swift$|Service\.swift$' || true)

if [ -z "$new_vm_or_service" ]; then
  exit 0
fi

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
    echo "[Tests Missing] New ViewModel/Service files without corresponding test files. Write unit tests for these: $(echo -e "$missing_tests" | tr '\n' ' '). Place tests in FitnessAppTests/ or the relevant Packages/*/Tests/ target."
    echo "$COVERAGE_HASH" > "$COVERAGE_HINT_SHOWN"
  fi
fi
