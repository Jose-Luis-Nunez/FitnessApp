#!/bin/bash
# Check 5: 5+ Swift files changed — suggest enforcement audit.
# Env: STATE_DIR, all_swift

ENFORCEMENT_SHOWN="$STATE_DIR/enforcement-audit.hint-hash.txt"

if [ -z "$all_swift" ]; then
  exit 0
fi

swift_count=$(echo "$all_swift" | grep -c '\.swift$' || true)
swift_count=${swift_count:-0}

if [ "$swift_count" -ge 5 ]; then
  CURRENT_HASH=$(echo "$all_swift" | sort | shasum -a 256 | cut -d' ' -f1)
  LAST_SHOWN_HASH=""
  if [ -f "$ENFORCEMENT_SHOWN" ]; then
    LAST_SHOWN_HASH=$(cat "$ENFORCEMENT_SHOWN" 2>/dev/null || echo "")
  fi
  if [ "$CURRENT_HASH" != "$LAST_SHOWN_HASH" ]; then
    echo "[Enforcement Audit Available] ${swift_count} Swift files changed. Consider running the reviewing-agent-effectiveness skill to verify all rules and hooks fired correctly."
    echo "$CURRENT_HASH" > "$ENFORCEMENT_SHOWN"
  fi
fi
