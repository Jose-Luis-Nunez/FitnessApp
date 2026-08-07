#!/bin/bash
# Development hint: new or changed tests must pass the risk-based selection gate.
# Env: STATE_DIR

SELECTION_HINT_SHOWN="$STATE_DIR/test-selection.hint-hash.txt"
TEST_SELECTION_CHECK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/test-domain-risk.sh
source "$TEST_SELECTION_CHECK_DIR/../lib/test-domain-risk.sh"

changed_paths=$(
  {
    git diff --name-only --diff-filter=AM HEAD 2>/dev/null
    git ls-files --others --exclude-standard 2>/dev/null
  } | grep -v '^$' | sort -u || true
)

test_candidates=$(
  printf '%s\n' "$changed_paths" |
    grep -E '(^|/)(Tests|FitnessAppUITests)/.*\.(swift|png)$' || true
)

logic_candidates=$(
  printf '%s\n' "$changed_paths" |
    grep -vE '(^|/)(Tests|TestSupport|FitnessAppUITests)/' |
    grep -iE '(ViewModel|Service)\.swift$' || true
)

domain_risk=$(printf '%s\n' "$changed_paths" | classify_test_domain_paths)

if [ -z "$test_candidates" ] && [ -z "$logic_candidates" ]; then
  exit 0
fi

selection_input=$(printf 'domain-risk:%s\ntests:\n%s\nlogic:\n%s\n' "$domain_risk" "$test_candidates" "$logic_candidates")
selection_hash=$(printf '%s' "$selection_input" | shasum -a 256 | cut -d' ' -f1)
last_selection_hash=""
if [ -f "$SELECTION_HINT_SHOWN" ]; then
  last_selection_hash=$(cat "$SELECTION_HINT_SHOWN" 2>/dev/null || true)
fi

if [ "$selection_hash" = "$last_selection_hash" ]; then
  exit 0
fi

message="[Risk-Based Test Selection — domain: $domain_risk] Apply .claude/references/test-selection-policy.md before adding, retaining, repairing, or re-recording tests. Prefer the lowest deterministic layer. Blocker paths require relevant passing evidence before completion; UI tests still require a critical journey that cannot be covered below UI. Snapshots require a stable reusable visual contract whose risk reduction exceeds baseline churn. Remove low-value legacy tests and snapshot-only dependencies instead of keeping them green mechanically."

if [ -n "$test_candidates" ]; then
  message="$message Test candidates: $(printf '%s' "$test_candidates" | tr '\n' ' ')"
fi

if [ -n "$logic_candidates" ]; then
  message="$message Logic candidates to assess for focused unit/integration coverage: $(printf '%s' "$logic_candidates" | tr '\n' ' ')"
fi

printf '%s\n' "$message"
printf '%s\n' "$selection_hash" > "$SELECTION_HINT_SHOWN"
