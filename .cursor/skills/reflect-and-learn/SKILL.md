---
name: reflect-and-learn
description: >-
  Analyze recent changes or corrections to extract reusable learnings and
  persist them as Cursor rules or skill updates. Use when the user asks to
  reflect, learn from mistakes, review what went wrong, or improve workflows
  based on past errors.
---

# Reflect and Learn

Turn one-time corrections into permanent knowledge by analyzing what went wrong and persisting the learning as a rule or skill update.

## When to Activate

- User says "reflect", "was habe ich falsch gemacht", "learn from this", "was kann ich besser machen"
- After a bug fix where the root cause was a convention violation
- After the user manually corrects agent output

## Reflection Process

### Step 1: Gather Evidence

Collect the changes from the current session:

```bash
git diff HEAD~1..HEAD   # last commit
git diff                # unstaged changes
```

If no git diff is available, review the conversation history for corrections the user made.

### Step 2: Categorize the Issue

Classify each finding into one of these buckets:

| Category | Example | Destination |
|---|---|---|
| **Style violation** | Used hardcoded color instead of AppStyle token | Update `swift-architecture.mdc` if pattern is missing **AND** add detection pattern to `reviewing-swift-code` skill |
| **Missed reuse** | Built custom sheet instead of using `WorkoutFormSheet` | Update `reviewing-swift-code` skill checklist **AND** `post-change-validation` reuse table |
| **Architecture drift** | Put business logic in View | Already covered — no action needed |
| **New pattern** | Recurring workflow not yet documented | Create new rule or skill |
| **Project-specific** | Naming convention, file placement | Update `architecture.md` |
| **Personal habit** | Forgetting to run validation after refactoring | Create personal rule in `~/.cursor/rules/` |

**Important:** Style violations and missed-reuse findings affect multiple files. Always update both the rule (`swift-architecture.mdc`) and the reviewing skill (`reviewing-swift-code/SKILL.md`) so the pattern is both enforced during writing and detected during review.

### Step 3: Propose the Learning

Present findings to the user in this format:

```
## Reflection Summary

### Finding 1: [Short title]
**What happened:** [Description of the mistake or correction]
**Root cause:** [Why it happened — missing rule, unclear docs, etc.]
**Proposed action:** [Specific file to update and what to add]
**Scope:** Project rule / Personal rule / Skill update / architecture.md update

### Finding 2: ...
```

### Step 4: Apply with Confirmation

After the user approves:

1. **Rule update** — edit the `.mdc` file in `.cursor/rules/` to add the new pattern
2. **Skill update** — edit the relevant `SKILL.md` to add a checklist item or detection pattern
3. **Architecture update** — edit `.cursor/references/architecture.md` to document the new convention
4. **New rule** — create a new `.mdc` file following the frontmatter format:

```yaml
---
description: Brief description of what this rule enforces
globs: "**/*.swift"
alwaysApply: false
---
```

Never apply changes without user confirmation. Always show the diff of what will change.

## What NOT to Persist

- One-off mistakes that won't recur
- Findings already covered by existing rules
- Overly specific patterns that only apply to a single file
- Temporary workarounds

## Examples of Good Learnings

- "Always check `SessionTrainingCache` before creating a new `ActiveSetViewModel`" -> add to architecture.md Known Architectural Notes
- "Date formatting in analytics must use `AnalyticsDateHelper`, not `DateFormatter` directly" -> already in rules, but add concrete BAD/GOOD example
- "After renaming a service method, grep all ViewModels for the old name" -> add to post-change-validation skill
