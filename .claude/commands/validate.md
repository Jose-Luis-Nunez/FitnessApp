---
description: Run risk-based, content-bound validation for current changes
---

# /validate

1. Run `bash .claude/hooks/lib/change-risk.sh classify`.
2. Follow `.claude/skills/reviewing-code-changes/SKILL.md`.
3. Green: perform the lightweight self-review and one relevant final test.
4. Yellow/red: use fresh reviewer and tester agents. The tester verifies an
   existing matching final result instead of repeating it.
5. Write code and test manifests with `validation-evidence.sh`.
6. Write stamps containing the matching `source_fingerprint`.
7. Run `.claude/hooks/tests/workflow-tests.sh` only when agent workflow files
   themselves changed.

Report risk, findings, test mode (`run` or `verify`), test counts, and evidence
fingerprint.
