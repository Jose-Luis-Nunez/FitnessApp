---
name: reviewing-agent-infrastructure
description: >-
  Validate and fix agent infrastructure after changes to .claude/ files.
  Checks reference integrity, agent-system-overview sync, description accuracy,
  handoff links, hook alignment, and name consistency. Uses a Verifier subagent
  to independently confirm findings before writing the stamp. Use after editing
  rules, skills, hooks, references, or when the user asks to reflect or improve
  the agent system.
---

# Reviewing Agent Infrastructure

Validate that agent-system files (.claude/) are consistent after changes. A Verifier subagent independently confirms results before the stamp is written.

## When to Activate

- After modifying files under `.claude/` (rules, skills, hooks, references)
- After `reviewing-agent-effectiveness` identifies gaps (NOT FIRED findings)
- User says "reflect", "learn from this", "improve agent system"
- After the user manually corrects agent output
- Handoff target from `debugging-ui-tests/SKILL.md` (via `reviewing-agent-effectiveness`) when a UI-test failure exposes infrastructure gaps that need closing

## Validation Checklist

**Read this file first, then** work through each category. Fix findings immediately.

### 1. Reference Integrity

Grep for **old names** of renamed/deleted skills, rules, or hooks across `.claude/`:

```bash
rg "old-skill-name" .claude/
```

Zero hits required. When a folder or conceptual layer was deleted, also grep for the layer name in prose text (descriptions, frontmatter, examples).

### 2. Overview Sync

Compare files on disk with tables in `.claude/references/agent-system-overview.md`:

- Every `.mdc` in `.claude/rules/` has a row in L2/L2g
- Every `SKILL.md` in `.claude/skills/*/` has a row in L3
- Every hook in `.claude/hooks/checks/` has a row in L5
- No rows reference files that no longer exist

### 3. Description Consistency

For each changed skill or rule, verify the frontmatter `description` accurately describes what the file does. Stale descriptions break Claude Code's skill triggering (Claude reads the description to decide when to invoke the skill).

### 4. Handoff Links

If skill A references skill B ("hand off to B"), verify:
- B exists at the referenced path
- B references A back (or lists A in "When to Activate")

### 5. Hook Alignment

If hooks or state references changed:
- Skill names in followup messages match actual skill folder names
- Stamp file paths match what skills write to
- State file paths match actual `state/` directory contents

### 6. Name Consistency

- YAML `name:` field matches the folder name
- H1 heading matches the skill/rule purpose

## Output

### Step 1: Full Report (in agent response)

Write the report with **all 6 section headings** — the hook checks for them:

```
## Agent Infrastructure Validation Report

**Files inspected:** N files under .claude/

### Reference Integrity
- [findings or "No issues"]

### Sync Issues
- [findings or "No issues"]

### Description Drift
- [findings or "No issues"]

### Handoff Links
- [findings or "No issues"]

### Hook Alignment
- [findings or "No issues"]

### Name Consistency
- [findings or "No issues"]

**Summary:** N total findings.
```

### Step 2: Spawn Verifier Subagent

After writing the report, spawn a **Verifier subagent** via the Task tool. The Verifier independently checks the results and writes the stamp. Do NOT write the stamp yourself.

The Verifier's role definition lives in `.claude/agents/verifier.md`. The `SubagentStop` hook detects `subagent_type: "verifier"` from the parent transcript and applies the verifier quality gate.

```
Task(
  subagent_type: "verifier",
  description: "Verify agent-infrastructure validation",
  prompt: """
Read .claude/agents/verifier.md for your full role definition and instructions.

CHANGED FILES:
<paste the list of changed .claude/ files>

REPORT FROM MAIN AGENT:
<paste the full report>

Return a one-line summary of your verdict.
"""
)
```

### Step 3: Confirm Stamp

After the Verifier returns, read `.claude/hooks/state/agent-infrastructure.stamp.md` and confirm it contains `result: PASS` and `verified_by: verifier-subagent`. If the Verifier reported FAIL, fix the issues and re-run from Step 1.

## Learnings

After validation, if findings came from mistakes or corrections, write a brief entry to `.claude/hooks/state/agent-infrastructure.log.md` (date, what was learned, which file was updated). Ask the user before persisting changes to rules or skills.
