---
name: reviewing-agent-infrastructure
description: >-
  Validate and fix agent infrastructure after changes to .cursor/ files.
  Checks reference integrity, enforcement-layers sync, description accuracy,
  handoff links, and hook alignment. Also turns corrections and audit findings
  into permanent rule and skill updates. Use after editing rules, skills, hooks,
  agents, or when the user asks to reflect or improve the agent system.
---

# Reviewing Agent Infrastructure

Validate that agent-system files (.cursor/) are consistent after changes, and persist learnings from mistakes into permanent updates. This is the equivalent of `reviewing-code-changes` for the agent infrastructure.

## When to Activate

- After modifying files under `.cursor/` (rules, skills, hooks, agents, references)
- After `reviewing-agent-effectiveness` identifies gaps (NOT FIRED findings)
- User says "reflect", "was habe ich falsch gemacht", "learn from this", "improve agent system"
- After the user manually corrects agent output
- After a bug fix where the root cause was a convention violation

## Validation Checklist

Work through each category. Fix findings immediately — do not defer.

### 1. Reference Integrity

Grep for any **old names** of renamed/deleted skills, rules, agents, or hooks across all `.cursor/` files:

```bash
rg "old-skill-name" .cursor/
```

Zero hits required. If any remain, update them.

### 2. enforcement-layers.md Sync

Compare the actual files on disk with the tables in `.cursor/references/enforcement-layers.md`:

- Every `.mdc` file in `.cursor/rules/` has a row in the L2 or L2g table
- Every `SKILL.md` in `.cursor/skills/*/` has a row in the L3 Skills table
- Every `.md` in `.cursor/agents/` has a row in the L3 Agents table
- Every hook in `.cursor/hooks/` has a row in the L4/L5 table
- No rows reference files that no longer exist

### 3. Description Consistency

For each changed skill or rule, verify the `description` in the frontmatter accurately describes what the file does. The description is used by Cursor for keyword matching — a stale description means the skill won't trigger correctly.

### 4. Handoff Links

If skill A references skill B (e.g. "hand off to B"), verify:
- B exists at the referenced path
- B references A back (or at least lists A as a trigger in its "When to Activate" section)

### 5. Hook Alignment

If `.cursor/hooks/post-task-check.sh` was changed or references were updated:
- Skill names in followup messages match actual skill folder names
- Stamp file paths match what skills write to
- State file paths in the hook match the actual `state/` directory contents

### 6. H1 and Name Consistency

- The YAML `name:` field matches the folder name
- The H1 heading (`# ...`) matches the skill/rule purpose (not a leftover from a previous name)

## Learning Workflow

When findings come from mistakes or corrections (not just rename/restructure), classify and persist them:

### Categorize the Issue

| Category | Example | Destination |
|---|---|---|
| **Style violation** | Used hardcoded color instead of AppStyle token | Update `swift-architecture.mdc` **AND** `reviewing-swift-code` skill |
| **Missed reuse** | Built custom sheet instead of using `WorkoutFormSheet` | Update `reviewing-swift-code` skill **AND** `reviewing-code-changes` reuse table |
| **Architecture drift** | Put business logic in View | Already covered — no action needed |
| **New pattern** | Recurring workflow not yet documented | Create new rule or skill |
| **Project-specific** | Naming convention, file placement | Update `architecture.md` |
| **Personal habit** | Forgetting to run validation after refactoring | Create personal rule in `~/.cursor/rules/` |

**Important:** Style violations and missed-reuse findings affect multiple files. Always update both the rule and the reviewing skill so the pattern is both enforced during writing and detected during review.

### Apply Changes

After the user approves findings:

1. **Rule update** — edit the `.mdc` file in `.cursor/rules/`
2. **Skill update** — edit the relevant `SKILL.md`
3. **Architecture update** — edit `.cursor/references/architecture.md`
4. **New rule** — create a new `.mdc` file with proper frontmatter

Never apply learning changes without user confirmation.

## What NOT to Persist

- One-off mistakes that won't recur
- Findings already covered by existing rules
- Overly specific patterns that only apply to a single file
- Temporary workarounds

## Output

### 1. Full Report (in agent response)

```
## Agent Infrastructure Validation Report

**Files inspected:** N files under .cursor/

### Reference Integrity
- `enforcement-layers.md:68` — references `old-skill-name/SKILL.md`, should be `new-skill-name/SKILL.md`

### Sync Issues
- `style-auditor.md` exists on disk but missing from L3 Agents table

### Description Drift
- `reviewing-code-changes/SKILL.md` — description says "post-change" but skill was renamed

### Learnings Applied
- Added "check SessionTrainingCache" to architecture.md Known Notes

**Summary:** N reference, N sync, N description, N learning items found.
```

### 2. Stamp file (for the hook)

Write a **minimal** stamp to `.cursor/hooks/state/agent-validation-stamp.md`:

```
date: 2026-04-12T17:00:00
result: PASS
files_inspected: 12
findings: 2
```
