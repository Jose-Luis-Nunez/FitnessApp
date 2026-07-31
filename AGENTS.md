# FitnessApp — Notes for Agents

A quick introduction; details live in the versioned `.claude/` files.

## Conventions and Architecture

- **Project rules (binding):** `.claude/rules/` — among others, Swift architecture, AppStyle, Docs-Sync, Build & Test, UI-State-Sync.
- **Structure inventory (Feature Map, Services, Models, Navigation, Shared Components):** `.claude/references/architecture-documentation.md` — update only the relevant section for public/structural changes; do not load the full file for local work.
- **Workflows:** `.claude/skills/` (one `SKILL.md` per skill).
- **Subagents:** `.claude/agents/` (reviewer, tester, verifier — via `Task(subagent_type: "<role>", …)`).
- **Slash commands:** `.claude/commands/` (e.g. `/validate`).
- **Hooks:** `.claude/settings.json` registers the `Stop` and `SubagentStop` hooks; scripts under `.claude/hooks/`.

`architecture-documentation.md` is **not** a replacement for the rules: it documents the **current structure**; the requirements live in the `.mdc` rules.

## Build and Tests (Xcode)

- Open the project: `FitnessApp.xcodeproj`
- Scheme: **FitnessApp** (shared under `FitnessApp.xcodeproj/xcshareddata/xcschemes/`)

Package tests use the pinned toolchain through:

```bash
scripts/test-affected-packages.sh FitnessTraining
```

The minimal non-negotiable Xcode settings live in
`.claude/rules/build-and-test.mdc`. Validation is risk-based and content-bound;
see `.claude/references/agent-system-overview.md`.

## What you do **not** have to do

- Do **not** rename `architecture-documentation.md` to `AGENTS.md` — it serves a different purpose and is firmly anchored in rules, hooks, and skills.
- Do not create a second, parallel architecture doc; `architecture-documentation.md` is the canonical reference.
