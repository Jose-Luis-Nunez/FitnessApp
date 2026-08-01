---
description: Validate before commit: run final risk-based, content-bound checks without staging or committing
---

# /validate — Validate Before Commit

Run this after implementation is complete, no known finding or product decision
remains open, and the intended commit is staged. The development Stop hook
provides only lightweight hints; this command produces the evidence required
by pre-commit.

This command validates only. It never stages files, creates or amends a commit,
or pushes changes.

1. Confirm the staged commit candidate is final: no overlapping unstaged
   changes, no pending finding/decision, and `git diff --cached --check` passes.
2. Resolve applicable ADR triggers before starting subagents.
3. Run `bash .claude/hooks/lib/change-risk.sh classify staged`.
4. Follow `.claude/skills/reviewing-code-changes/SKILL.md`.
5. Green: perform the lightweight self-review and one relevant final test.
6. Yellow/red: use one fresh reviewer as the senior-quality review, then start
   the tester only after all Bug findings are fixed. The tester verifies an
   existing matching final result instead of repeating it.
7. Do not report stale test/infrastructure stamps as code findings before their
   respective validation phase.
8. Write code and test manifests from staged contents with
   `validation-evidence.sh write <manifest> staged`.
9. Write stamps containing the matching `source_fingerprint`.
10. Run `.claude/hooks/tests/workflow-tests.sh` only when agent workflow files
   themselves changed.

Report risk, findings, test mode (`run` or `verify`), test counts, and evidence
fingerprint.
