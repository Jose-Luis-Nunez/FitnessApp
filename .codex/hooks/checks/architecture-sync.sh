#!/bin/bash
# Check 2: Current public/structural Swift changes — is architecture synced?
# Private refactors, layout-only edits, test-only changes, and presentation-only
# work intentionally do not trigger this check. AppStyle tokens never trigger it:
# the architecture reference's own "AppStyle Tokens" section states it does not
# mirror token names or values, so demanding an edit there had nothing to write.
# Env: all_swift, CHANGE_RISK

ARCH_FILE=".claude/references/architecture-documentation.md"
arch_changed=$(git diff --name-only HEAD 2>/dev/null | grep "$ARCH_FILE" || true)

new_feature_files=$(git diff --name-only --diff-filter=A HEAD 2>/dev/null | grep '^FitnessApp/Features/' || true)
new_navigation=$(git diff HEAD -- '*.swift' 2>/dev/null | grep '^+' | grep -E 'NavigationDestination|case [a-zA-Z].*Navigation' || true)
# A new file under a shared path is only architecturally relevant when it
# carries a contract. A presentation-only SwiftUI View — one public View type
# whose entire public surface is `body` and a no-argument `init` — owns nothing
# worth documenting, so it is filtered out here rather than reported and then
# dismissed by hand. Anything that hands callers a vocabulary is a contract:
# observable state, a public protocol/actor/class/enum, a public func/let/var/
# static, a public typealias, a nested or sibling public struct, or an
# initializer taking parameters (it names the collaborators this type needs).
#
# Known gap, deliberately not closed: members of a `public extension` inherit
# public visibility WITHOUT the `public` keyword, so none of the greps below see
# them. A `public extension View` carrying the modifier form of the same
# component is the case that exists today and is correctly treated as the same
# surface spelled twice — but a genuine contract added only inside such an
# extension would be invisible here. Like the added-files-only scope above, this
# is acceptable for a hint emitter and not for a gate.
presentation_only() {
  local file="$1"
  grep -qE '^[[:space:]]*public struct [A-Za-z0-9_]+: View\b' "$file" || return 1
  [ "$(grep -cE '^[[:space:]]*public[[:space:]]+struct\b' "$file")" -eq 1 ] || return 1
  grep -qE '^[[:space:]]*(@Observable|public[[:space:]]+(protocol|actor|class|enum|typealias)\b)' "$file" && return 1
  grep -qE '^[[:space:]]*public[[:space:]]+(func|let|static)\b' "$file" && return 1
  # Every `public init` must be argument-free. Matching "a non-`)` follows the
  # paren" missed the multi-line form, where the parameters start on the next
  # line — which is how any initializer with more than two arguments is written
  # in this codebase, so the most contract-heavy components escaped the filter.
  grep -E '^[[:space:]]*public[[:space:]]+init\b' "$file" \
    | grep -qvE '^[[:space:]]*public[[:space:]]+init\([[:space:]]*\)' && return 1
  grep -E '^[[:space:]]*public[[:space:]]+var\b' "$file" \
    | grep -qvE '^[[:space:]]*public[[:space:]]+var[[:space:]]+body\b' && return 1
  return 0
}

new_shared=""
while IFS= read -r shared_candidate; do
  [ -n "$shared_candidate" ] || continue
  [ -f "$shared_candidate" ] || continue
  presentation_only "$shared_candidate" && continue
  new_shared="${new_shared} ${shared_candidate}"
done <<EOF
$(git diff --name-only --diff-filter=A HEAD 2>/dev/null | grep -E '^FitnessApp/Shared/|^Packages/Fitness(UI|PersistenceUI)/Sources/' || true)
EOF
new_usecases=$(git diff --name-only --diff-filter=A HEAD 2>/dev/null | grep 'UseCases/' || true)
service_arch_surface=$(git diff HEAD -- \
  '*Service.swift' '*Storage.swift' '*Container.swift' '*Coordinator.swift' | \
  grep -E '^[+-][[:space:]]*(@Observable|public[[:space:]]+((private|internal)\(set\)[[:space:]]+)?(final[[:space:]]+)?(actor|class|struct|enum|protocol|func|var|let)\b)' || true)
domain_surface=$(git diff HEAD -- 'Packages/FitnessCore/Sources/**/*.swift' 2>/dev/null | grep -E '^[+-].*public (struct|class|enum|protocol|func|var|let)' || true)

reasons=""
if [ -n "$new_feature_files" ] && [ -z "$arch_changed" ]; then
  reasons="${reasons} New feature files added."
fi
if [ -n "$new_navigation" ] && [ -z "$arch_changed" ]; then
  reasons="${reasons} NavigationDestination cases changed."
fi
if [ -n "$new_shared" ] && [ -z "$arch_changed" ]; then
  reasons="${reasons} New shared components added."
fi
if [ -n "$new_usecases" ] && [ -z "$arch_changed" ]; then
  reasons="${reasons} New Use Cases added."
fi
if [ -n "$service_arch_surface" ] && [ -z "$arch_changed" ]; then
  reasons="${reasons} Public or state-ownership service surface changed."
fi
if [ -n "$domain_surface" ] && [ -z "$arch_changed" ]; then
  reasons="${reasons} Public FitnessCore domain surface changed."
fi

if [ -n "$reasons" ]; then
  echo "[Architecture Sync Required]${reasons} Update only the relevant current-state section. Use reviewing-code-changes/references/architecture-routing.md."
fi
