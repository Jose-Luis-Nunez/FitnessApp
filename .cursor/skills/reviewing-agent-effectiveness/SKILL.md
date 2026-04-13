---
name: reviewing-agent-effectiveness
description: >-
  Diagnose which agent enforcement mechanisms (rules, hooks, skills)
  fired during a task and which did not. Produces a FIRED / NOT FIRED / N/A
  report per mechanism. Use when the user asks to review what worked, check
  enforcement, audit the agent system, or evaluate whether rules gripped.
  For fixing gaps found, hand off to reviewing-agent-infrastructure.
---

# Reviewing Agent Effectiveness

## Context

The FitnessApp project uses a layered defense-in-depth architecture:

- **L2 — Always-Apply Rules** (`.cursor/rules/*.mdc` with `alwaysApply: true`): Loaded into every chat. ~80% compliance.
- **L3 — Skills** (`.cursor/skills/*/SKILL.md`): Triggered by keyword match from user prompt. ~85-90% compliance.
- **L3 — Commands** (`.cursor/commands/*.md`): Explicit user-triggered workflows. ~85-90% compliance.
- **L5 — Stop Hook** (`.cursor/hooks/post-task-check.sh`): Deterministic checks after agent finishes. 100% execution.
- **L4 — Pre-Commit Hook** (`.git/hooks/pre-commit`): Blocks bad commits. 100% execution.

## When to Use

After any non-trivial implementation task, especially:
- New features (2+ Swift files)
- Refactoring across multiple files
- Bug fixes touching coordinators or shared state
- When the user asks "was hat gegriffen?" / "what rules fired?" / "enforcement audit"

## Audit Process

### Step 1: Identify the Task Scope

Determine what was done in the task being audited:
- What files were created/modified?
- What type of task was it? (new feature, refactoring, bug fix, test writing)
- Was it in the current chat or a different chat? (if different, read the transcript)

### Step 2: Check Each Enforcement Mechanism

Walk through every mechanism and determine: FIRED / NOT FIRED / NOT APPLICABLE.

#### A: Always-Apply Rules

| ID | Rule | File | What to Check |
|---|---|---|---|
| R1 | Triggered Rule Notice | `code-changes-enforcement.mdc` | Did the agent mention "post-change validation will be required" early? |
| R2 | DEVELOPER_DIR | `build-and-test.mdc` | Were all `xcodebuild` calls prefixed with `DEVELOPER_DIR`? Was `swift test`/`swift build` avoided? |
| R3 | Architecture Sync | `architecture-documentation-sync.mdc` | Was `architecture-documentation.md` updated when structural changes occurred? See `reviewing-code-changes` skill for trigger map. |
| R4 | Co-Author Trailer | AGENTS.md rule | If a commit was made, does it include the `Co-authored-by: Cursor` trailer? |
| R5 | Agent Infra Enforcement | `agent-infrastructure-enforcement.mdc` | If .cursor/ files changed, was agent-infrastructure validation mentioned early? Did the agent suggest learnings after mistakes? |

#### C: Skills

| ID | Skill | File | Trigger Condition | What to Check |
|---|---|---|---|---|
| S1 | Create Feature | `create-feature/SKILL.md` | User asks to create new feature/screen/view | Was the skill read and followed? Were tests written? |
| S2 | Reviewing Code Changes | `reviewing-code-changes/SKILL.md` | Swift files changed OR user asks to review code | Was the full checklist followed? Was stamp written (if post-change)? |
| S3 | Reviewing Test Quality | `reviewing-test-quality/SKILL.md` | User asks to review tests | Was the checklist followed? |
| S5 | Writing UI Tests | `writing-ui-tests/SKILL.md` | User asks to write UI tests | Was the skill read? |
| S6 | Updating UI Tests | `updating-ui-tests/SKILL.md` | User asks to fix/update UI tests | Was the skill read? |

#### D: Hooks

| ID | Hook | File | What to Check |
|---|---|---|---|
| H1 | Check 1: Validation Stamp | `post-task-check.sh` | Was `validation-stamp.md` present and fresh (< 10 min)? Did the grind loop fire? |
| H2 | Check 2: Docs-Sync | `post-task-check.sh` | Were structural changes detected? Was `architecture-documentation.md` updated? |
| H3 | Check 3: Test-Run Stamp | `post-task-check.sh` | Were test files changed? Was `test-stamp.md` present? |
| H4 | Check 4: Tests Exist | `post-task-check.sh` | Were new ViewModel/Service files created? Do corresponding test files exist? |
| H5 | Pre-Commit: Validation | `.git/hooks/pre-commit` | Would a commit be blocked for missing validation? |
| H6 | Pre-Commit: No print() | `.git/hooks/pre-commit` | Are there `print()` statements in production code? |
| H7 | Pre-Commit: architecture-documentation.md | `.git/hooks/pre-commit` | Would a commit be blocked for stale architecture-documentation.md? |

### Step 3: Build the Report

For each mechanism, assign a status and record evidence:

```
| ID | Mechanism | Status | Evidence | Triggered By |
|---|---|---|---|---|
| R1 | Triggered Notice | FIRED | "post-change validation will be required" in first response | alwaysApply: true |
| R3 | AppStyle Tokens | FIRED | 17 new tokens in AppStyle.swift, 0 hardcoded values | alwaysApply: true |
| H4 | Tests Exist | NOT FIRED | New ProfileViewModel.swift without ProfileViewModelTests.swift | Design gap |
| S3 | Test Quality Review | N/A | User did not request test review | Correct |
```

### Step 4: Visualize the Trigger Chain

Create a mermaid graph showing which mechanisms triggered which actions, and where gaps occurred. Use solid arrows for successful triggers, dashed arrows for failures.

### Step 5: Gap Analysis

For each NOT FIRED finding:
1. **Is it a gap or correct behavior?** (N/A = correct, NOT FIRED = potential gap)
2. **Severity: should this be fixed?** (critical = blocks quality, minor = nice-to-have, skip = correct behavior)

### Step 5.1: Hand Off to Improving-Agent-Infrastructure

For each gap with status NOT FIRED that represents a real deficiency (not N/A):
run the `reviewing-agent-infrastructure` skill to persist the fix as a rule or skill update.
Do not implement fixes inline in the audit report — the audit is a diagnosis,
not a treatment.

### Step 6: Summary

```
## Enforcement Audit Summary
- Task: <description>
- Files changed: <count>
- Mechanisms checked: <total>
- FIRED: <count> (<percentage>)
- NOT FIRED: <count> (gaps)
- N/A: <count> (correct)
- Gaps to fix: <list with IDs>
```

## Output

The complete report should be presented to the user. Do NOT write it to a file unless asked — it is a conversation artifact, not a persistent stamp.
