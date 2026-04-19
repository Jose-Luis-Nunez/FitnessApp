#!/bin/bash
# install-hooks.sh
#
# Configures this clone of the repository to use the versioned hooks under
# `.githooks/` instead of the per-clone `.git/hooks/`.
#
# Run this ONCE after cloning the repository, then again whenever the team
# adds a new hook. Idempotent — safe to re-run.
#
# Why: pre-commit checks (Swift validation report, ADR-required, UI-state-sync,
# architecture-doc freshness) protect architectural decisions documented in
# docs/adr/. Without this setup, those checks only run on the original author's
# machine — which means a 5-person team can silently regress.

set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "ERROR: not inside a git repository." >&2
  exit 1
}

cd "$REPO_ROOT"

if [ ! -d .githooks ]; then
  echo "ERROR: .githooks/ directory not found in repo root." >&2
  echo "  Are you in the right repository?" >&2
  exit 1
fi

CURRENT=$(git config --get core.hooksPath 2>/dev/null || echo "")
if [ "$CURRENT" = ".githooks" ]; then
  echo "OK: core.hooksPath is already set to .githooks"
else
  git config core.hooksPath .githooks
  echo "OK: core.hooksPath set to .githooks"
fi

chmod +x .githooks/* 2>/dev/null || true

echo ""
echo "Installed hooks:"
ls -1 .githooks/ | sed 's/^/  - /'
echo ""
echo "Next: run a no-op commit on a Swift change to verify the chain fires."
