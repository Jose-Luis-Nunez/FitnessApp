#!/bin/bash
# Check 8: Duplicate Domain-State Holders (Bug 1 class) detected in working tree?
# Pattern: non-blocking one-time hint.
# Env: CONTENT, STATE_DIR, all_swift, HAS_QUESTION
#
# Fires when the diff introduces `@State private var XViewModel` AND a UUID-keyed
# VM cache already exists somewhere in the codebase. Real blocking is up to the
# reviewer subagent (see state-services-review.md).

if [ "$HAS_QUESTION" -gt 0 ]; then
  exit 0
fi

if [ -z "$all_swift" ]; then
  exit 0
fi

# Did the diff add a new @State VM?
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

HAS_NEW_STATE_VM=$(echo "$ALL_DIFF" | grep -cE '^\+.*@State[[:space:]]+private[[:space:]]+var[[:space:]]+\w*ViewModel\b' || true)
HAS_NEW_STATE_VM=${HAS_NEW_STATE_VM:-0}

if [ "$HAS_NEW_STATE_VM" -lt 1 ]; then
  exit 0
fi

# Does a UUID-keyed VM cache already exist somewhere?
# Use git ls-files to scope to tracked sources only (excludes .build, DerivedData, etc.)
CACHE_HITS=""
TRACKED_SOURCES=$(git ls-files 'Packages/*/Sources/**/*.swift' 'FitnessApp/**/*.swift' 2>/dev/null | head -500 || true)
if [ -n "$TRACKED_SOURCES" ]; then
  CACHE_HITS=$(echo "$TRACKED_SOURCES" | xargs grep -En 'var[[:space:]]+[A-Za-z_]+ViewModels[[:space:]]*:[[:space:]]*\[UUID' 2>/dev/null | head -3 || true)
fi

if [ -z "$CACHE_HITS" ]; then
  exit 0
fi

# Dedupe
HINT_HASH_FILE="$STATE_DIR/duplicate-state.hint-hash.txt"
CUR_HASH=$(echo "$ALL_DIFF$CACHE_HITS" | shasum -a 256 | cut -d' ' -f1)
if [ -f "$HINT_HASH_FILE" ] && [ "$(cat "$HINT_HASH_FILE" 2>/dev/null)" = "$CUR_HASH" ]; then
  exit 0
fi
echo "$CUR_HASH" > "$HINT_HASH_FILE"

cat <<EOF
[Hint] Duplicate Domain-State Holders. Diff introduces a new '@State private var ...ViewModel'; a UUID-keyed VM cache already exists in:
$CACHE_HITS
Two lifecycles for one identity = sync bug. Prefer @Bindable on @Model, @Environment-injected single source, or pure-rendering view. See .claude/skills/reviewing-code-changes/references/state-services-review.md.
EOF
