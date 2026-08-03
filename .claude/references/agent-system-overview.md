# Agent System Overview

`.claude/` is canonical. `.agents/` and `.codex/` are generated runtime
adapters. All runtimes write local evidence under `.claude/hooks/state/`.

## Validation Flow

```text
Swift diff
  → change-risk.sh: green | yellow | red
  → development Stop hook: deduplicated design hints only
  → user freezes the complete working-tree candidate
  → `/validate`: all-change diff/ADR preflight, then matched review references
  → green: main-agent review/test
    yellow/red: one senior-quality reviewer, then tester(run|verify)
  → worktree content manifests + PASS stamps
  → user stages unchanged reviewed contents
  → pre-commit checks the exact staged candidate
```

Validation is content-bound, not time-bound. Final manifests hash every file
in the frozen working-tree candidate, including untracked files and excluding
only generated evidence state. Any later candidate edit invalidates the
evidence immediately; unchanged evidence does not expire. After validation,
pre-commit accepts only a staged candidate whose path/hash manifest exactly
equals the reviewed/tested one.

## Risk Policy

| Risk | Typical change | Required workflow |
|---|---|---|
| Green | ≤2 local presentation files; no state/API/data signal | Main-agent base review + one relevant final test/snapshot |
| Yellow | Logic, ViewModel/use case, public UI | Fresh reviewer + one final test run or tester verification |
| Red | Schema, storage, DI, coordinator, navigation, concurrency, package/public domain boundary, multi-package, or 10+ production files | Reviewer + tester + affected tests + app build + relevant UI tests; ADR when architectural |

Classification is conservative. Agents may raise but never lower risk.

## Rules

| File | Purpose |
|---|---|
| `code-changes-enforcement.mdc` | Risk-routed, content-bound Swift validation |
| `build-and-test.mdc` | Minimal pinned Xcode constraints and command routing |
| `architecture-documentation-sync.mdc` | Current-state docs for structural/public changes only |
| `ui-state-sync-enforcement.mdc` | Glob-routed ban on generic counter + polling UI sync |
| `agent-infrastructure-enforcement.mdc` | Verifier only for executable agent-system files |

## Skills

| Skill | Purpose |
|---|---|
| `create-feature` | Scaffold a SwiftUI feature using project conventions |
| `debugging-ui-tests` | Diagnose failing XCUITests |
| `deep-research` | Citation-backed research |
| `reviewing-agent-effectiveness` | Explicit workflow/cost audit; never file-count-triggered |
| `reviewing-agent-infrastructure` | Validate agent runtime and spawn verifier |
| `reviewing-code-changes` | Risk classifier, routed review, test-once evidence |
| `reviewing-test-quality` | Explicit unit/integration test-quality review |
| `updating-ui-tests` | Modernize existing UI tests |
| `writing-ui-tests` | Add new UI tests |

`reviewing-code-changes/references/` holds conditional checklists for base,
SwiftUI, SwiftData, state/services, tests, and architecture routing. Only
matched references are loaded.

Codex-only source-command adapters live under `.agents/skills/source-command-*`.

## Commands and Scripts

| File | Purpose |
|---|---|
| `.claude/commands/validate.md` | Review and validate every current working-tree change before staging; Git authority is canonical in `AGENTS.md` |
| `.claude/commands/buildApp.md` | Build/install/launch command |
| `scripts/test-affected-packages.sh` | Run each requested package test action once |
| `scripts/sync-agent-runtime.sh` | Generate/check Codex skills, hooks, and roles |
| `scripts/generate-codex-agent.py` | Generate TOML role from canonical Markdown |
| `scripts/install-hooks.sh` | Configure `.githooks` as Git hooks path |

## Development Stop Hook

`post-task-check.sh` does not require final evidence or subagents. It emits a
deduplicated hint only when it detects a likely issue in the working tree:

| Check | Type | Purpose |
|---|---|---|
| `architecture-sync.sh` | Hint | Structural/public change has current-state documentation |
| `test-coverage.sh` | Hint | New ViewModel/Service has a test file |
| `ui-state-sync.sh` | Hint | Generic counter + polling smell |
| `duplicate-state.sh` | Hint | New View-owned VM conflicts with keyed cache |
| `predicate-smell.sh` | Hint | SwiftData predicate/query hazards |
| `adr-required.sh` | Hint | Architectural trigger lacks ADR/exception |

Effectiveness audits are explicit and never triggered by ordinary file counts.

## Commit Evidence Checks

The following retained check scripts are not Stop-hook entries. They define the
content-bound evidence contract used by the final validation flow, workflow
fixtures, and pre-commit enforcement:

| Check | Purpose |
|---|---|
| `code-validation.sh` | Validates review manifest/stamp against current Swift contents and risk |
| `test-execution.sh` | Validates final test manifest/stamp against current Swift contents and risk |
| `agent-infrastructure.sh` | Validates verifier manifest/stamp against current infrastructure contents |

Shared libraries:

- `change-risk.sh` — conservative risk classifier.
- `validation-evidence.sh` — complete-candidate manifests, hashes, and exact
  worktree/staged verification; evidence-state files are excluded to avoid a
  self-referential fingerprint.
- `agent-infrastructure-evidence.sh` — manifests and hashes for executable
  agent-system changes.
- `adr-triggers.sh` — shared ADR detection.

Fixture tests live in `.claude/hooks/tests/workflow-tests.sh`.

## Pre-Commit

`.githooks/pre-commit` blocks:

1. staged Swift whose complete staged candidate differs from code-review evidence;
2. staged Swift whose complete staged candidate differs from final-test evidence;
3. production `print()`;
4. architectural triggers without ADR/exception;
5. generic counter + polling UI sync;
6. structural/public changes without architecture documentation.
7. executable agent infrastructure whose staged candidate differs from the
   exact independently verified infrastructure candidate.

Stamps cannot be bypassed by `touch` or partial staging: the staged path/hash
manifest must equal the previously reviewed worktree manifest.

## Subagents

| Role | Required for | Output |
|---|---|---|
| Reviewer | Yellow/red Swift changes | Findings + code manifest/stamp |
| Tester | Yellow/red Swift changes | `run` or `verify` + test manifest/stamp |
| Verifier | Executable agent-infrastructure changes | Infrastructure stamp |

Codex agents use `fork_turns: "none"` and read the workspace directly. Prompts
contain risk, paths, and relevant references—not the diff or conversation.

`subagent-gate.sh` verifies role output and matching evidence. Canonical roles
live in `.claude/agents/`; generated TOML adapters live in `.codex/agents/`.

## Infrastructure Boundary

Verifier required:

- `.claude/rules`, skills, hooks, agents, commands, settings;
- `.claude/references/agent-system-overview.md`;
- `.agents/skills`, `.codex/hooks`, `.codex/agents`, `.codex/hooks.json`;
- `.githooks`, `AGENTS.md`, and agent/build workflow scripts.

Verifier not required:

- `architecture-documentation.md`;
- `ui-test-conventions.md`;
- capabilities and user flows;
- runtime state and plans.

## Runtime Evidence

All files below are local and ignored:

| Artifact | Meaning |
|---|---|
| `code-changes.manifest.tsv` | Hash per file in the complete validated candidate |
| `code-changes.stamp.md` | Risk, reviewer, result, manifest fingerprint |
| `test-execution.manifest.tsv` | Hash per file in the complete tested candidate |
| `test-execution.stamp.md` | Run/verify mode, command, result, fingerprint |
| `agent-infrastructure.manifest.tsv` | Hash per verified infrastructure file |
| `agent-infrastructure.stamp.md` | Independent verifier result bound to exact infrastructure contents |
| `*.scratchpad.json` / `*.hint-hash.txt` | Bounded hook state |

## Adapter Sync

Run:

```bash
scripts/sync-agent-runtime.sh --write
scripts/sync-agent-runtime.sh --check
```

The first generates adapters; the second fails on content drift or stale Codex
hook files. Product references are not mirrored.
