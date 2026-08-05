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
| `hooks/post-task-check.sh` | Development `Stop` hook orchestrator — emits deduplicated design/architecture hints only; final validation and evidence belong to `/validate`. |
| `hooks/subagent-gate.sh` | `SubagentStop` hook — role-specific quality gates for `reviewer` / `tester` / `verifier`. |
| `hooks/checks/*.sh` | Individual checks invoked by the orchestrator. |
| `hooks/state/` | Runtime artifacts: stamps, scratchpads, hint hashes (gitignored). |
| `settings.json` | Registers the `Stop` and `SubagentStop` hooks. |

## Build & Test — Cheat Sheet

`swift test` / `swift build` are forbidden — SwiftData macros require Xcode. Always use `xcodebuild` with `DEVELOPER_DIR` set (see `.claude/rules/build-and-test.mdc` for the exact commands, the iPhone 17 Pro Max simulator setup, and the parallel fast-test loop).

## Workflow Conventions

- **Swift change → run `reviewing-code-changes`** when the user requests final validation. During development, the `Stop` hook emits lightweight hints and does not require final stamps or tests.
- **Agent-infrastructure change → run `reviewing-agent-infrastructure`**, then spawn the Verifier subagent. The required `agent-infrastructure.stamp.md` must match the schema enforced by the verifier and hooks.
- **Structural Swift change** (new feature, service, model, navigation, AppStyle token, shared component) → also update `.claude/references/architecture-documentation.md` in the same task.
- **UI test fails** → use the `debugging-ui-tests` skill before tweaking pipelines or timeouts.

## Review Preferences

- Treat impossible internal input as an invariant violation instead of silently
  normalizing it. For example, workout-scoped `ExerciseModel` collections must
  not contain the same Exercise ID twice; ViewModels should assert or surface
  that violation rather than `Set`-deduplicating it. Defensive normalization is
  appropriate only at a documented public/external boundary whose contract
  explicitly permits unordered or duplicate input.
- Do not turn a failed read into a cached empty result. Keep "successfully
  loaded, no data" distinguishable from "load failed" so retries remain
  possible and persistence errors stay visible.
