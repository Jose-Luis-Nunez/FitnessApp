---
description: Validate before commit: run final risk-based, content-bound checks without staging or committing
---

# /validate — Validate Before Commit

Run this after implementation is complete and no known finding or product
decision remains open. The complete working tree is the validation candidate;
it is staged only after review succeeds and only by an actor authorized under
`AGENTS.md`. The development Stop hook
provides only lightweight hints; this command produces the evidence required
by pre-commit.

Git authority is canonical in the repository-root `AGENTS.md`. This command
reviews all tracked modifications and untracked files without changing Git
state.

1. Confirm the complete working-tree candidate: no pending finding/decision,
   at least one changed path, and `git diff HEAD --check` passes. Include
   staged, unstaged, and untracked files in the changed-file inventory.
2. Resolve applicable ADR triggers before starting subagents.
3. Run both classifiers:
   - `bash .claude/hooks/lib/change-risk.sh classify worktree` for review routing.
   - `bash .claude/hooks/lib/test-domain-risk.sh classify worktree` for test depth.
4. Follow `.claude/skills/reviewing-code-changes/SKILL.md`.
5. Green: perform the lightweight self-review and one relevant final test.
6. Yellow/red: use one fresh reviewer as the senior-quality review, then start
   the tester only after all Bug findings are fixed. The tester verifies an
   existing matching final result instead of repeating it.
7. Do not report stale test/infrastructure stamps as code findings before their
   respective validation phase.
8. Write code and test manifests from all working-tree contents with
   `validation-evidence.sh write <manifest> worktree`.
9. Write stamps containing the matching `source_fingerprint`.
10. Run `.claude/hooks/tests/workflow-tests.sh` only when agent workflow files
    themselves changed.

After PASS, staging the complete unchanged candidate preserves evidence:
pre-commit requires the staged manifest to equal the reviewed/tested worktree
manifest exactly. Staging only a subset requires a separate validation of that
explicit candidate. Any candidate edit requires `/validate` again.

Report review risk, test-domain risk, findings, test mode (`run` or `verify`),
test counts, and evidence fingerprint.
