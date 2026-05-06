# FitnessApp — Claude Code Project Guide

This file is loaded automatically by Claude Code on every session in this repo.
For the human-readable agent overview see [AGENTS.md](AGENTS.md).

## Project Layout

- `FitnessApp/` — Xcode app target (`FitnessApp.xcodeproj`, scheme `FitnessApp`).
- `Packages/` — SwiftPM packages (`FitnessExercise`, `FitnessTraining`, `FitnessAnalytics`, `FitnessStorage`, `FitnessProfile`, `FitnessUI`, `FitnessWorkouts`, …). All unit tests live here, **not** in an app-level test target.
- `FitnessAppUITests/` — UI tests; require the dedicated `FitnessApp UITests` scheme (sets the `UITESTING` Swift flag).

## Agent Infrastructure (`.claude/`)

| Folder | Purpose |
|---|---|
| `rules/*.mdc` | Always-apply or glob-scoped project rules (Swift architecture, AppStyle, build & test, doc-sync, UI-state-sync, agent-infra enforcement). |
| `skills/<name>/SKILL.md` | Triggered workflows (create-feature, reviewing-code-changes, debugging-ui-tests, deep-research, …). Claude reads the frontmatter `description` to decide when to invoke them. |
| `commands/*.md` | Slash commands (e.g. `/validate`). |
| `agents/*.md` | Subagent definitions — invoke via `Task(subagent_type: "<name>", …)`. Available: `reviewer`, `tester`, `verifier`. |
| `references/*.md` | Read-only architecture & convention docs (canonical: `architecture-documentation.md`). |
| `hooks/post-task-check.sh` | `Stop` hook orchestrator — runs 10 checks (validation stamps, architecture sync, test execution, anti-patterns, ADR triggers). |
| `hooks/subagent-gate.sh` | `SubagentStop` hook — role-specific quality gates for `reviewer` / `tester` / `verifier`. |
| `hooks/checks/*.sh` | Individual checks invoked by the orchestrator. |
| `hooks/state/` | Runtime artifacts: stamps, scratchpads, hint hashes (gitignored). |
| `settings.json` | Registers the `Stop` and `SubagentStop` hooks. |

## Build & Test — Cheat Sheet

`swift test` / `swift build` are forbidden — SwiftData macros require Xcode. Always use `xcodebuild` with `DEVELOPER_DIR` set (see `.claude/rules/build-and-test.mdc` for the exact commands, the iPhone 17 Pro Max simulator setup, and the parallel fast-test loop).

## Workflow Conventions

- **Swift change → run `reviewing-code-changes`** (or its Reviewer + Tester subagents). The `Stop` hook will block until a fresh `code-changes.stamp.md` exists.
- **`.claude/` change → run `reviewing-agent-infrastructure`**, then spawn the Verifier subagent. Required stamp: `agent-infrastructure.stamp.md` with all 8 fields.
- **Structural Swift change** (new feature, service, model, navigation, AppStyle token, shared component) → also update `.claude/references/architecture-documentation.md` in the same task.
- **UI test fails** → use the `debugging-ui-tests` skill before tweaking pipelines or timeouts.
