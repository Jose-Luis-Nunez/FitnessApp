---
name: reviewing-agent-infrastructure
description: >-
  Validate executable agent infrastructure after changes to rules, skills,
  hooks, agents, commands, runtime adapters, AGENTS.md, or the agent overview.
  Checks reference integrity, agent-system-overview sync, description accuracy,
  handoff links, hook alignment, and name consistency. Uses a Verifier subagent
  to independently confirm findings before writing the stamp. Product
  architecture and UI-test references are outside this trigger.
---

# Reviewing Agent Infrastructure

Validate that canonical executable agent-system files and generated runtime
adapters are consistent. A Verifier independently confirms results.

## When to Activate

- After modifying executable agent infrastructure: rules, skills, hooks,
  agents, commands, runtime adapters, `AGENTS.md`, or the agent-system overview
- After `reviewing-agent-effectiveness` identifies gaps (NOT FIRED findings)
- User says "reflect", "learn from this", "improve agent system"
- After the user manually corrects agent output
- Handoff target from `debugging-ui-tests/SKILL.md` (via `reviewing-agent-effectiveness`) when a UI-test failure exposes infrastructure gaps that need closing

## Validation Checklist

**Read this file first, then** work through each category. Fix findings immediately.

### 1. Reference Integrity

Grep for **old names** of renamed/deleted skills, rules, or hooks across
`.claude/` and `.codex/`:

```bash
rg "old-skill-name" .claude/ .codex/
```

Zero hits required. When a folder or conceptual layer was deleted, also grep for the layer name in prose text (descriptions, frontmatter, examples).

When hook responsibility or validation sequencing changed, also run a broad
semantic search before the verifier and inspect every hit rather than checking
only known exact phrases:

```bash
rg -ni 'stop.?hook|gate|blocking|validation evidence' .claude/ .codex/ .agents/
```

Legitimate historical/test references may remain, but stale instructions that
assign final evidence to the development Stop hook must not.

### 2. Overview Sync

Compare files on disk with tables in `.claude/references/agent-system-overview.md`:

- Every `.mdc` in `.claude/rules/` has a row in L2/L2g
- Every `SKILL.md` in `.claude/skills/*/` has a row in L3
- Every hook in `.claude/hooks/checks/` and its generated
  `.codex/hooks/checks/` counterpart has a row in L5
- No rows reference files that no longer exist

### 3. Description Consistency

For each changed skill or rule, verify the frontmatter `description` accurately
describes what the file does. Stale descriptions break skill routing.

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

Write the exact executable-infrastructure manifest before verification:

```bash
bash .claude/hooks/lib/agent-infrastructure-evidence.sh write \
  .claude/hooks/state/agent-infrastructure.manifest.tsv staged
bash .claude/hooks/lib/agent-infrastructure-evidence.sh fingerprint \
  .claude/hooks/state/agent-infrastructure.manifest.tsv
```

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

After writing the report, spawn a **Verifier subagent** with fresh context. In
Codex use `fork_turns: "none"`. The Verifier independently checks the results
and writes the stamp. Do NOT write the stamp yourself.

The Claude Code role definition lives in `.claude/agents/verifier.md`; the
Codex runtime equivalent lives in `.codex/agents/verifier.toml`. Both write
their stamp to the canonical `.claude/hooks/state/` directory. The
`SubagentStop` hook detects `subagent_type: "verifier"` from the parent
transcript and applies the verifier quality gate.

```
Task(
  subagent_type: "verifier",
  description: "Verify agent-infrastructure validation",
  prompt: """
Read `.claude/agents/verifier.md` in Claude Code, or
`.codex/agents/verifier.toml` in Codex, for your full role definition and instructions.

CHANGED FILES:
<list paths; do not paste the diff or conversation>

REPORT FROM MAIN AGENT:
<paste the full report>

Return a one-line summary of your verdict.
"""
)
```

### Step 3: Confirm Stamp

After the Verifier returns, confirm the manifest matches the exact current
contents and that the stamp contains `result: PASS`,
`verified_by: verifier-subagent`, and the manifest's `source_fingerprint`.
If the Verifier reported FAIL, fix the issues and re-run from Step 1.

## Learnings

After validation, if findings came from mistakes or corrections, write a brief entry to `.claude/hooks/state/agent-infrastructure.log.md` (date, what was learned, which file was updated). Ask the user before persisting changes to rules or skills.
