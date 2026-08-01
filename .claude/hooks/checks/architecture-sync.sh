#!/bin/bash
# Check 2: Current public/structural Swift changes — is architecture synced?
# Private refactors, layout-only edits, token value swaps, and test-only changes
# intentionally do not trigger this check.
# Env: all_swift, CHANGE_RISK

ARCH_FILE=".claude/references/architecture-documentation.md"
arch_changed=$(git diff --name-only HEAD 2>/dev/null | grep "$ARCH_FILE" || true)

new_feature_files=$(git diff --name-only --diff-filter=A HEAD 2>/dev/null | grep '^FitnessApp/Features/' || true)
appstyle_surface=$(git diff HEAD -- '*/AppStyle.swift' 2>/dev/null | grep -E '^[+-][[:space:]]*public static (let|var)' || true)
new_navigation=$(git diff HEAD -- '*.swift' 2>/dev/null | grep '^+' | grep -E 'NavigationDestination|case [a-zA-Z].*Navigation' || true)
new_shared=$(git diff --name-only --diff-filter=A HEAD 2>/dev/null | grep -E '^FitnessApp/Shared/|^Packages/Fitness(UI|PersistenceUI)/Sources/' || true)
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
if [ -n "$appstyle_surface" ] && [ -z "$arch_changed" ]; then
  reasons="${reasons} AppStyle public tokens added, renamed, or removed."
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
