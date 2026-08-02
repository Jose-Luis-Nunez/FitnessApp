---
name: source-command-validate
description: Route final-validation requests to the canonical /validate workflow.
---

# source-command-validate — Validate Before Commit

Use when the user invokes `/validate`, says "validate before commit" or "ready
to validate", asks for final commit validation/checks, or says they are ready
to commit.

Read the canonical Git-authority rule in the repository-root `AGENTS.md`, then
follow `.claude/commands/validate.md` exactly. This adapter adds no validation
steps or Git authority of its own.
