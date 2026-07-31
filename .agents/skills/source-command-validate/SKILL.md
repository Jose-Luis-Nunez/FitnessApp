---
name: source-command-validate
description: Run risk-based, content-bound validation for current changes
---

# source-command-validate

Use when the user invokes the migrated `validate` command.

1. Classify with `.claude/hooks/lib/change-risk.sh`.
2. Follow `.agents/skills/reviewing-code-changes/SKILL.md`.
3. Run final required tests once; reuse exact matching evidence through tester
   `verify` mode.
4. Record code/test manifests and stamps with matching content fingerprints.
5. Report risk, findings, test mode, counts, and fingerprint.
