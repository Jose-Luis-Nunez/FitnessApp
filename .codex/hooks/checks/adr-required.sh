#!/bin/bash
# Check 10: structural change detected — ADR present in working tree?
# Pattern: Hint — agent gets followup_message, can self-correct.
# Real blocking happens in .git/hooks/pre-commit (separate Check 5).
# Env: STATE_DIR, HOOKS_DIR, all_swift, HAS_QUESTION

if [ "$HAS_QUESTION" -gt 0 ]; then
  exit 0
fi

source "$HOOKS_DIR/lib/adr-triggers.sh"

# Trigger detection scans Swift + Package.swift only. Markdown / hooks / skills
# can mention the same patterns as documentation examples without being a real
# structural change.
DIFF=$(git diff HEAD -- '*.swift' 'Packages/Package.swift' 'Packages/*/Package.swift' 2>/dev/null || true)
DIFF_FILES=$(git diff HEAD --name-only -- '*.swift' 'Packages/Package.swift' 'Packages/*/Package.swift' 2>/dev/null || true)

# Untracked Swift / Package.swift files contribute too.
UNTRACKED_FILES=$(git ls-files --others --exclude-standard 2>/dev/null | grep -E '\.swift$|^Packages(/[^/]+)?/Package\.swift$' || true)
if [ -n "$UNTRACKED_FILES" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if [ -f "$f" ]; then
      DIFF="${DIFF}
$(sed 's/^/+/' "$f" 2>/dev/null || true)"
    fi
  done <<< "$UNTRACKED_FILES"
  DIFF_FILES="${DIFF_FILES}
${UNTRACKED_FILES}"
fi

# But: ADR-presence check looks at ALL diff (including markdown).
ADR_FILES=$(git diff HEAD --name-only 2>/dev/null || true)
ADR_FILES="${ADR_FILES}
$(git ls-files --others --exclude-standard 2>/dev/null || true)"

if [ -z "$DIFF" ]; then
  exit 0
fi

detect_adr_triggers "$DIFF" "$DIFF_FILES"

if [ ${#ADR_TRIGGERS[@]} -eq 0 ]; then
  exit 0
fi

# ADR added in same diff?
if echo "$ADR_FILES" | grep -qE '^docs/adr/[0-9]+.*\.md$'; then
  exit 0
fi

if adr_exception_stamp_fresh; then
  exit 0
fi

# Dedupe per trigger combination
HINT_HASH_FILE="$STATE_DIR/adr-required.hint-hash.txt"
TRIGGER_KEY=$(echo "${ADR_TRIGGERS[@]}" | tr ' ' '\n' | sort | shasum -a 256 | cut -d' ' -f1)
if [ -f "$HINT_HASH_FILE" ] && [ "$(cat "$HINT_HASH_FILE" 2>/dev/null)" = "$TRIGGER_KEY" ]; then
  exit 0
fi
echo "$TRIGGER_KEY" > "$HINT_HASH_FILE"

cat <<EOF
[Hint] adr-required: structural change detected without an accompanying ADR. Triggers: ${ADR_TRIGGERS[*]}. Either:
  - add an ADR under docs/adr/NNNN-title.md (template in docs/adr/README.md), or
  - touch .claude/hooks/state/adr-exception.stamp.md with a one-line reason (valid 24h)
The pre-commit hook (Check 5) will block the commit otherwise.
EOF
