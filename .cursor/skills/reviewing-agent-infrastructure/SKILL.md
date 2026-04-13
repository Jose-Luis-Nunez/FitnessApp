---
name: reviewing-agent-infrastructure
description: >-
  Validate and fix agent infrastructure after changes to .cursor/ files.
  Checks reference integrity, agent-system-overview sync, description accuracy,
  handoff links, and hook alignment. Also turns corrections and audit findings
  into permanent rule and skill updates. Use after editing rules, skills, hooks,
  references, or when the user asks to reflect or improve the agent system.
---

# Reviewing Agent Infrastructure

Validate that agent-system files (.cursor/) are consistent after changes, and persist learnings from mistakes into permanent updates. This is the equivalent of `reviewing-code-changes` for the agent infrastructure.

## When to Activate

- After modifying files under `.cursor/` (rules, skills, hooks, references)
- After `reviewing-agent-effectiveness` identifies gaps (NOT FIRED findings)
- User says "reflect", "was habe ich falsch gemacht", "learn from this", "improve agent system"
- After the user manually corrects agent output
- After a bug fix where the root cause was a convention violation

## Validation Checklist

Work through each category. Fix findings immediately — do not defer.

### 1. Reference Integrity

Grep for any **old names** of renamed/deleted skills, rules, or hooks across all `.cursor/` files:

```bash
rg "old-skill-name" .cursor/
```

Zero hits required. If any remain, update them.

When an entire **folder or conceptual layer** was deleted (not just a single file), also grep for the layer name in prose text — descriptions, frontmatter, examples, and "When to Activate" sections. Stale references hide in prose that no import or path check catches.

### 2. agent-system-overview.md Sync

Compare the actual files on disk with the tables in `.cursor/references/agent-system-overview.md`:

- Every `.mdc` file in `.cursor/rules/` has a row in the L2 or L2g table
- Every `SKILL.md` in `.cursor/skills/*/` has a row in the L3 Skills table

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

## Active Rules Acknowledgment

At the start of every task, silently check which always-apply rules are active. Mention a rule ONLY when the task triggers a specific action:
- Swift files changed -> "Post-change validation will be required."
- Structural changes -> "architecture-documentation.md will need updating."
- Test files changed -> "Tests should be executed."
- `.cursor/` files changed -> "Agent-infrastructure validation will be required."

Do NOT list all rules mechanically.

## Self-Improvement Protocol

When any of the following occurs during a session:
- You fix a bug caused by violating a project convention
- The user corrects your output (e.g. wrong component, wrong token, wrong placement)
- You discover a pattern not yet covered by existing rules or skills

Then at the end of the task (after the fix is applied), briefly note:

1. **What went wrong** — one sentence
2. **Which rule/skill should cover this** — file path or "new rule needed"
3. **Proposed addition** — the specific line or pattern to add

Ask the user: "Soll ich dieses Learning in den Rules/Skills persistieren?"

Do NOT interrupt the current task to reflect. Complete the fix first, then suggest the learning.

## Repetition Detection

When the user requests a workflow manually that resembles a previous manual request (e.g. "analysiere die Tests", "review test quality", "ist der Code testbar"):

1. Check if a skill already covers this workflow (search `.cursor/skills/`)
2. If no skill exists and the pattern has appeared 2+ times across sessions, suggest: "This is a recurring workflow. Shall I create a skill for it?"
3. If confirmed, create a new skill under `.cursor/skills/`

This turns repeated L1 requests (conversation) into L3 enforcement (skill/template).

## Self-Review Rule

When the user asks you to evaluate your own implementation ("ist das gut?", "is the solution good?", "review this"):

- Do NOT merely describe known weaknesses or trade-offs — **fix them immediately**.
- Mentioning a problem without resolving it wastes a round-trip and forces the user to request the fix separately.
- If you identify a risk (e.g. magic number, fragile alignment, missing `.fixedSize()`), treat it as a finding and apply the fix in the same response.

## Learning Workflow

When findings come from mistakes or corrections (not just rename/restructure), classify and persist them:

### Categorize the Issue

| Category | Example | Destination |
|---|---|---|
| **Style violation** | Used hardcoded color instead of AppStyle token | Update `reviewing-code-changes` skill |
| **Missed reuse** | Built custom sheet instead of using `WorkoutFormSheet` | Update `reviewing-code-changes` skill reuse table |
| **Architecture drift** | Put business logic in View | Already covered — no action needed |
| **New pattern** | Recurring workflow not yet documented | Create new skill |
| **Project-specific** | Naming convention, file placement | Update `architecture-documentation.md` |
| **Personal habit** | Forgetting to run validation after refactoring | Create personal rule in `~/.cursor/rules/` |

### Apply Changes

After the user approves findings:

1. **Skill update** — edit the relevant `SKILL.md`
2. **Architecture update** — edit `.cursor/references/architecture-documentation.md`
3. **New skill** — create a new folder under `.cursor/skills/` with `SKILL.md`

Write a brief entry to `.cursor/hooks/state/agent-infrastructure.log.md` after each learning (date, what was learned, which file was updated).

Never apply learning changes without user confirmation.

## Structural Principles

These are hard-won lessons. Check for violations when reviewing infrastructure changes.

### No Duplicated Logic

Every piece of knowledge (checklist, convention, process) must have **one** canonical location. Other files reference it — they never copy it.

| Pattern | Problem | Fix |
|---|---|---|
| File A copies checklist from Skill B | A drifts out of sync when B is updated | A references B as single source of truth |
| Two files define the same validation rules | Updates to one miss the other | Consolidate into one file, reference from the other |
| Hook message duplicates skill instructions | Message becomes stale when skill changes | Hook message points to skill path |

When reviewing changes: if the same logic appears in 2+ files, flag it. One must become the reference, the other must link to it.

### Two Layers Only

The system has exactly two enforcement layers:
- **Rules** — enforce (when something must happen)
- **Skills** — execute (how to do it)

References (`.cursor/references/`) are shared knowledge files read by skills. Hooks are deterministic checks. Neither is a separate conceptual layer.

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
- `agent-system-overview.md:68` — references `old-skill-name/SKILL.md`, should be `new-skill-name/SKILL.md`

### Sync Issues
- `some-skill/SKILL.md` exists on disk but missing from L3 Skills table

### Description Drift
- `reviewing-code-changes/SKILL.md` — description says "post-change" but skill was renamed

### Learnings Applied
- Added "check SessionTrainingCache" to architecture-documentation.md Known Notes

**Summary:** N reference, N sync, N description, N learning items found.
```

### 2. Stamp file (for the hook)

Write a **minimal** stamp to `.cursor/hooks/state/agent-infrastructure.stamp.md`:

```
date: 2026-04-12T17:00:00
result: PASS
files_inspected: 12
findings: 2
```
