---
name: "source-command-validate"
description: "Run code-change validation on recently changed Swift files"
---

# source-command-validate

Use this skill when the user asks to run the migrated source command `validate`.

## Command Template

# /validate

Execute the following steps in order:

1. Run `git diff --name-only HEAD` and `git ls-files --others --exclude-standard` to identify all changed/new Swift files.

2. If fewer than 2 Swift files changed, report "Trivial change — validation skipped." and stop.

3. Read the `reviewing-code-changes` skill at `.agents/skills/reviewing-code-changes/SKILL.md`.

4. Follow the complete validation checklist from the skill:
   - Section 1: Dead Code
   - Section 2: Reuse Opportunities
   - Section 3: AppStyle Consistency
   - Section 4: Referential Integrity
   - Section 5: Cleanup Sweep
   - Section 6: State Propagation (if ViewModels/Coordinators changed)
   - Section 7: Architecture Quality (if services/protocols/coordinators changed)

5. If test files (`*Tests*.swift` or `*TestSupport*`) are among the changed files, run the affected package tests using `xcodebuild` (see `build-and-test` rule). Write a test stamp to `.claude/hooks/state/test-execution.stamp.md` (date, PASS/FAIL, package, test count).

6. Write a validation stamp to `.claude/hooks/state/code-changes.stamp.md` (date, PASS/FAIL, file count, finding count).

7. If test files changed, note whether the `reviewing-test-quality` skill would be relevant (but do NOT run it automatically — that is a separate, explicit review the user can request).

8. Report findings. Fix any issues found before reporting done.
