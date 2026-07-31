#!/bin/bash
# Check 7: UI-state-sync anti-pattern (Int-counter + polling loop) detected in working tree?
# Pattern: non-blocking one-time suggestion before commit.
# Env: CONTENT, STATE_DIR, all_swift, HAS_QUESTION
#
# Runs against working-tree diff (HEAD vs working) so the agent sees the smell
# BEFORE staging+committing. Real blocking happens in .git/hooks/pre-commit Check 4.

if [ "$HAS_QUESTION" -gt 0 ]; then
  exit 0
fi

if [ -z "$all_swift" ]; then
  exit 0
fi

# Combined diff: HEAD vs working tree (covers staged + unstaged) + brand-new untracked files
TRACKED_DIFF=$(git diff HEAD -- '*.swift' 2>/dev/null || true)
UNTRACKED_DIFF=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if [ -f "$f" ]; then
    UNTRACKED_DIFF="${UNTRACKED_DIFF}
$(sed 's/^/+/' "$f" 2>/dev/null || true)"
  fi
done <<< "$(git ls-files --others --exclude-standard 2>/dev/null | grep '\.swift$' || true)"

ALL_DIFF="${TRACKED_DIFF}${UNTRACKED_DIFF}"

if [ -z "$ALL_DIFF" ]; then
  exit 0
fi

HAS_COUNTER=$(echo "$ALL_DIFF" | grep -cE '^\+.*\b(changeVersion|mutationVersion|dataGeneration|revision)\b[[:space:]]*:[[:space:]]*Int\b' || true)
HAS_COUNTER=${HAS_COUNTER:-0}
HAS_LOOP=$(echo "$ALL_DIFF" | grep -cE '^\+.*while[[:space:]]+!Task\.isCancelled' || true)
HAS_LOOP=${HAS_LOOP:-0}

if [ "$HAS_COUNTER" -gt 0 ] && [ "$HAS_LOOP" -gt 0 ]; then
  # Skip if exception stamp is fresh
  EXCEPTION_STAMP=".claude/hooks/state/ui-state-sync-exception.stamp.md"
  if [ -f "$EXCEPTION_STAMP" ]; then
    AGE=$(( $(date +%s) - $(stat -f %m "$EXCEPTION_STAMP" 2>/dev/null || echo 0) ))
    if [ "$AGE" -lt 86400 ]; then
      exit 0
    fi
  fi

  # Dedupe: don't re-emit if same diff signature recently flagged
  HINT_HASH_FILE="$STATE_DIR/ui-state-sync.hint-hash.txt"
  CUR_HASH=$(echo "$ALL_DIFF" | shasum -a 256 | cut -d' ' -f1)
  if [ -f "$HINT_HASH_FILE" ] && [ "$(cat "$HINT_HASH_FILE" 2>/dev/null)" = "$CUR_HASH" ]; then
    exit 0
  fi
  echo "$CUR_HASH" > "$HINT_HASH_FILE"

  cat <<'EOF'
[Hint] ui-state-sync-enforcement.mdc anti-pattern detected: Int-counter (changeVersion/mutationVersion/dataGeneration/revision: Int) + 'while !Task.isCancelled' polling loop in same diff. This is semantic polling disguised as observation. Prefer @Observable fachlich, @Query on @Model, @Bindable, or AsyncSequence with payload. Pre-commit hook will block this commit unless .claude/hooks/state/ui-state-sync-exception.stamp.md (with ADR link) exists. See .claude/rules/ui-state-sync-enforcement.mdc.
EOF
fi
