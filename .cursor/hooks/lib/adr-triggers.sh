#!/bin/bash
# Shared library: detect structural changes that require an ADR.
#
# Usage:
#   source "$HOOKS_DIR/lib/adr-triggers.sh"
#   detect_adr_triggers "<diff_text>" "<file_list>"
#   echo "${ADR_TRIGGERS[@]}"   # array, may be empty
#
# Triggers (each one is independent):
#   1. new-observable-in-service          — '@Observable' added in *Service.swift
#   2. observation-tracking-outside-view  — withObservationTracking added outside *View.swift
#   3. polling-loop-in-service-or-vm      — 'while !Task.isCancelled' added in Service/ViewModel
#   4. schema-change                      — @Attribute / @Relationship added under Models/
#   5. new-package                        — new Packages/<name>/Package.swift
#   6. container-change                   — Container.swift modified

detect_adr_triggers() {
  local diff_text="$1"
  local file_list="$2"
  ADR_TRIGGERS=()

  if [ -z "$diff_text" ]; then
    return 0
  fi

  # Trigger 1
  if echo "$diff_text" | grep -qE '^\+.*@Observable' \
     && echo "$file_list" | grep -qE 'Service\.swift$'; then
    ADR_TRIGGERS+=("new-observable-in-service")
  fi

  # Trigger 2
  if echo "$diff_text" | grep -qE '^\+.*withObservationTracking' \
     && ! echo "$file_list" | grep -qE 'View\.swift$'; then
    ADR_TRIGGERS+=("observation-tracking-outside-view")
  fi

  # Trigger 3
  if echo "$diff_text" | grep -qE '^\+.*while[[:space:]]+!Task\.isCancelled' \
     && echo "$file_list" | grep -qE '(Service|ViewModel)\.swift$'; then
    ADR_TRIGGERS+=("polling-loop-in-service-or-vm")
  fi

  # Trigger 4 — schema change in Models/
  if echo "$diff_text" | grep -qE '^\+[[:space:]]*(@Attribute|@Relationship)' \
     && echo "$file_list" | grep -qE '/Models/.*\.swift$'; then
    ADR_TRIGGERS+=("schema-change")
  fi

  # Trigger 5 — new Package.swift created (not modified)
  # Only count files that are newly added with a 'name:' line in the diff.
  if echo "$file_list" | grep -qE '^Packages/[^/]+/Package\.swift$' \
     && echo "$diff_text" | grep -qE '^\+.*name:[[:space:]]*"'; then
    ADR_TRIGGERS+=("new-package")
  fi

  # Trigger 6 — Container.swift change (any modification)
  if echo "$file_list" | grep -qE 'Container\.swift$'; then
    ADR_TRIGGERS+=("container-change")
  fi
}

# True (return 0) if a fresh ADR exception stamp exists (< 24h).
adr_exception_stamp_fresh() {
  local stamp=".cursor/hooks/state/adr-exception.stamp.md"
  if [ -f "$stamp" ]; then
    local age
    age=$(( $(date +%s) - $(stat -f %m "$stamp" 2>/dev/null || echo 0) ))
    if [ "$age" -lt 86400 ]; then
      return 0
    fi
  fi
  return 1
}
