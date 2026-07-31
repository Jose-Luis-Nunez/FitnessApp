# Agent System Overview

`.claude/` is canonical. `.agents/` and `.codex/` are generated runtime
adapters. All runtimes write local evidence under `.claude/hooks/state/`.

## Validation Flow

```text
Swift diff
  → change-risk.sh: green | yellow | red
  → load base review + matched specialist references
  → green: main-agent review/test
    yellow/red: fresh reviewer + tester(run|verify)
  → content manifests + PASS stamps
  → Stop hook checks working contents
  → pre-commit checks staged blobs
```

Validation is content-bound, not time-bound. Changing a relevant file
invalidates evidence immediately; unchanged evidence does not expire.

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
| `.claude/commands/validate.md` | Explicit risk-based validation |
| `.claude/commands/buildApp.md` | Build/install/launch command |
| `scripts/test-affected-packages.sh` | Run each requested package test action once |
| `scripts/sync-agent-runtime.sh` | Generate/check Codex skills, hooks, and roles |
| `scripts/generate-codex-agent.py` | Generate TOML role from canonical Markdown |
| `scripts/install-hooks.sh` | Configure `.githooks` as Git hooks path |

## Stop Hook

`post-task-check.sh` runs these checks:

| Check | Type | Purpose |
|---|---|---|
| `code-validation.sh` | Blocking | Code manifest/stamp matches exact working contents and risk |
| `architecture-sync.sh` | Hint | Structural/public change has current-state documentation |
| `test-execution.sh` | Blocking | One final test result matches exact working contents |
| `test-coverage.sh` | Hint | New ViewModel/Service has a test file |
| `agent-infrastructure.sh` | Blocking | Executable agent-system changes have verifier evidence |
| `ui-state-sync.sh` | Hint | Generic counter + polling smell |
| `duplicate-state.sh` | Hint | New View-owned VM conflicts with keyed cache |
| `predicate-smell.sh` | Hint | SwiftData predicate/query hazards |
| `adr-required.sh` | Hint | Architectural trigger lacks ADR/exception |

Effectiveness audits are explicit and never triggered by ordinary file counts.

Shared libraries:

- `change-risk.sh` — conservative risk classifier.
- `validation-evidence.sh` — manifests, hashes, worktree/staged verification.
- `agent-infrastructure-evidence.sh` — exact fingerprint for executable
  agent-system changes.
- `adr-triggers.sh` — shared ADR detection.

Fixture tests live in `.claude/hooks/tests/workflow-tests.sh`.

## Pre-Commit

`.githooks/pre-commit` blocks:

1. staged Swift not covered by content-bound code review evidence;
2. staged Swift not covered by final test evidence;
3. production `print()`;
4. architectural triggers without ADR/exception;
5. generic counter + polling UI sync;
6. structural/public changes without architecture documentation.

Stamps cannot be bypassed by `touch`; staged blob hashes must match the
manifest.

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
| `code-changes.manifest.tsv` | Hash per validated product/test file |
| `code-changes.stamp.md` | Risk, reviewer, result, manifest fingerprint |
| `test-execution.manifest.tsv` | Hash per tested product/test file |
| `test-execution.stamp.md` | Run/verify mode, command, result, fingerprint |
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
