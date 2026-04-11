---
description: Run post-change validation on recently changed Swift files
---

# /validate

Execute the following steps in order:

1. Run `git diff --name-only HEAD` and `git ls-files --others --exclude-standard` to identify all changed/new Swift files.

2. If fewer than 2 Swift files changed, report "Trivial change — validation skipped." and stop.

3. Read the `post-change-validation` skill at `.cursor/skills/post-change-validation/SKILL.md`.

4. Follow the complete validation checklist from the skill:
   - Section 1: Dead Code
   - Section 2: Reuse Opportunities
   - Section 3: AppStyle Consistency
   - Section 4: Referential Integrity
   - Section 5: Cleanup Sweep
   - Section 6: State Propagation (if ViewModels/Coordinators changed)
   - Section 7: Architecture Quality (if services/protocols/coordinators changed)

5. Write a validation stamp to `.cursor/hooks/state/validation-stamp.md` (date, PASS/FAIL, file count, finding count).

6. Report findings. Fix any issues found before reporting done.
