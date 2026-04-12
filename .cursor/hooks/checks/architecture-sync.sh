#!/bin/bash
# Check 2: Structural Swift changes — was architecture-documentation.md updated?
# Env: all_swift

ARCH_FILE=".cursor/references/architecture-documentation.md"
arch_changed=$(git diff --name-only HEAD 2>/dev/null | grep "$ARCH_FILE" || true)

new_feature_files=$(git diff --name-only --diff-filter=A HEAD 2>/dev/null | grep '^FitnessApp/Features/' || true)
new_appstyle=$(git diff --name-only HEAD 2>/dev/null | grep 'AppStyle.swift' || true)
new_navigation=$(git diff HEAD -- FitnessApp/FitnessAppApp.swift 2>/dev/null | grep '^+' | grep 'case [a-z]' | grep -v 'case \.' || true)
new_shared=$(git diff --name-only --diff-filter=A HEAD 2>/dev/null | grep '^FitnessApp/Shared/' || true)
new_usecases=$(git diff --name-only --diff-filter=A HEAD 2>/dev/null | grep 'UseCases/' || true)
new_services=$(git diff --name-only HEAD 2>/dev/null | grep -E 'Service\.swift|Container\.swift' || true)

reasons=""
if [ -n "$new_feature_files" ] && [ -z "$arch_changed" ]; then
  reasons="${reasons} New feature files added."
fi
if [ -n "$new_navigation" ] && [ -z "$arch_changed" ]; then
  reasons="${reasons} NavigationDestination cases changed."
fi
if [ -n "$new_appstyle" ] && [ -z "$arch_changed" ]; then
  reasons="${reasons} AppStyle.swift modified."
fi
if [ -n "$new_shared" ] && [ -z "$arch_changed" ]; then
  reasons="${reasons} New shared components added."
fi
if [ -n "$new_usecases" ] && [ -z "$arch_changed" ]; then
  reasons="${reasons} New Use Cases added."
fi
if [ -n "$new_services" ] && [ -z "$arch_changed" ]; then
  reasons="${reasons} Services or Container registrations changed."
fi

if [ -n "$reasons" ]; then
  echo "[Architecture Sync Required]${reasons} Update .cursor/references/architecture-documentation.md now. See the reviewing-code-changes skill, section 'Architecture Sync', for the trigger map."
fi
