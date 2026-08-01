---
name: source-command-validate
description: Validate before commit: run final risk-based, content-bound checks without staging or committing
---

# source-command-validate — Validate Before Commit

Use when the user invokes `/validate`, says "validate before commit" or "ready
to validate", asks for final commit validation/checks, or says they are ready
to commit. Validate only:
never stage files, create/amend a commit, or push changes.

1. Require a final staged commit candidate with no overlapping unstaged files,
   no pending finding/product decision, and a clean `git diff --cached --check`.
2. Resolve applicable ADR triggers before spawning subagents.
3. Classify the staged candidate with
   `.claude/hooks/lib/change-risk.sh classify staged`.
4. Follow `.agents/skills/reviewing-code-changes/SKILL.md`; its yellow/red
   reviewer is the single senior-quality review, and the tester runs only after
   all Bug findings are fixed.
5. Run final required tests once; reuse exact matching evidence through tester
   `verify` mode.
6. Record code/test manifests from staged contents and write stamps with
   matching content fingerprints.
7. Report risk, findings, test mode, counts, and fingerprint.
