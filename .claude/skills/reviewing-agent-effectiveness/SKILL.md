---
name: reviewing-agent-effectiveness
description: >-
  Audit whether risk classification, content-bound evidence, targeted skills,
  tests, hooks, and subagents behaved as intended. Use explicitly for workflow
  audits or after an enforcement failure; it is never auto-triggered by file count.
---

# Reviewing Agent Effectiveness

Use this skill only when the user requests a workflow audit, when an expected
gate failed, or when `debugging-ui-tests` hands off an infrastructure gap. It
diagnoses; fixes hand off to `reviewing-agent-infrastructure`.

## Audit

### 1. Scope and Risk

- List changed production/test files.
- Run `change-risk.sh classify`.
- Confirm the observed risk was not lower than the expected risk.

### 2. Prompt Routing

- Green: main-agent base review only.
- Yellow/red: fresh reviewer and tester without conversation history.
- Confirm only matching specialist references were loaded.
- Confirm the reviewer read only relevant architecture sections.

### 3. Evidence and Tests

- Code and test manifests match current contents.
- Stamps contain the matching `source_fingerprint`.
- Green may use `main-agent`; yellow/red require reviewer/tester subagents.
- Count final test commands. An equivalent successful command must occur once,
  not once in the main agent and again in the tester.
- A tester using `verify` inspected the recorded result rather than re-running.

### 4. Deterministic Gates

| ID | Gate | Expected |
|---|---|---|
| R1 | Risk notice | Mentioned before Swift work |
| R2 | Xcode rule | Pinned DEVELOPER_DIR; no `swift test` |
| R3 | Architecture sync | Only structural/public changes |
| H1 | Code evidence | Exact content manifest + PASS stamp |
| H2 | Test evidence | One final matching run/verification |
| H3 | Coverage hint | New ViewModel/Service has tests |
| H4 | Agent infrastructure | Only executable agent-system changes |
| H5 | UI state | Counter + polling smell detected |
| H6 | Duplicate state | Duplicate state-owner smell detected |
| H7 | Predicate | SwiftData predicate smell detected |
| H8 | ADR | True architecture triggers only |
| H9 | Pre-commit | Staged blobs covered by evidence |

Assign `FIRED`, `NOT FIRED`, or `N/A` with concrete evidence. Missing behavior is
a gap only when its trigger applied.

### 5. Cost Report

Report:

- subagents spawned and whether they inherited conversation context;
- review references loaded;
- final test commands and duplicate count;
- verifier usage and trigger;
- avoidable agent runs;
- wall-clock duration per executed command plus uninstrumented gaps; never
  label a residual subtraction as fingerprint/evidence runtime;
- approximate prompt savings using actual file/context sizes when available.

## Output

Return one compact table plus:

- risk verdict;
- useful mechanisms;
- avoidable work;
- gaps to hand off;
- estimated token/runtime savings.

Do not write a stamp or modify infrastructure during the audit.
