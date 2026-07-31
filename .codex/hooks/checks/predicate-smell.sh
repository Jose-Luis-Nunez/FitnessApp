#!/bin/bash
# Check 9: SwiftData predicate anti-patterns detected in working tree?
# Pattern: non-blocking one-time hint.
# Env: STATE_DIR, all_swift, HAS_QUESTION
#
# Heuristic flags only — final judgement is the reviewer subagent's
# (see swiftdata-review.md).

if [ "$HAS_QUESTION" -gt 0 ]; then
  exit 0
fi

if [ -z "$all_swift" ]; then
  exit 0
fi

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

# Only check if the diff actually adds a #Predicate
HAS_PREDICATE=$(echo "$ALL_DIFF" | grep -cE '^\+.*#Predicate' || true)
HAS_PREDICATE=${HAS_PREDICATE:-0}

if [ "$HAS_PREDICATE" -lt 1 ]; then
  exit 0
fi

WARNINGS=""

# 14a/b — optional/force chain. Look in added lines around #Predicate.
PREDICATE_BLOCK=$(echo "$ALL_DIFF" | grep -A2 -E '^\+.*#Predicate' | grep -E '^\+' || true)
if echo "$PREDICATE_BLOCK" | grep -qE '\?\.|!\.'; then
  WARNINGS="${WARNINGS}
  - 14a/b: Optional or force chain in #Predicate ('?.' or '!.'). Denormalise the foreign key onto the child @Model."
fi

# 14c — persistentModelID
if echo "$ALL_DIFF" | grep -qE '^\+.*persistentModelID[[:space:]]*=='; then
  WARNINGS="${WARNINGS}
  - 14c: Predicate compares persistentModelID. Prefer 'id == UUID' if the @Model has @Attribute(.unique) var id."
fi

# 14e — @ModelActor introduced together with #Predicate
if echo "$ALL_DIFF" | grep -qE '^\+.*@ModelActor'; then
  WARNINGS="${WARNINGS}
  - 14e: Diff introduces both @ModelActor and #Predicate. Verify @Query consumers see updates after background save (ADR required)."
fi

if [ -z "$WARNINGS" ]; then
  exit 0
fi

# Dedupe
HINT_HASH_FILE="$STATE_DIR/predicate-smell.hint-hash.txt"
CUR_HASH=$(echo "$WARNINGS$ALL_DIFF" | shasum -a 256 | cut -d' ' -f1)
if [ -f "$HINT_HASH_FILE" ] && [ "$(cat "$HINT_HASH_FILE" 2>/dev/null)" = "$CUR_HASH" ]; then
  exit 0
fi
echo "$CUR_HASH" > "$HINT_HASH_FILE"

cat <<EOF
[Hint] SwiftData predicate anti-patterns in diff:${WARNINGS}
See .claude/skills/reviewing-code-changes/references/swiftdata-review.md.
EOF
