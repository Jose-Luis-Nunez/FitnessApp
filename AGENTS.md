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

## UI Iteration and Git Authority

- Treat UI and design changes as a development iteration by default: keep the
  work in the working tree and do not stage it.
- Do not start `/validate`, a reviewer or tester subagent, or write final
  validation evidence unless the user explicitly asks for final validation.
- **Git authority boundary (canonical):** agents do not stage, create, amend,
  rewrite, or push commits by default. An agent may perform these Git actions
  only when the user's instruction begins with the exact quoted prefix
  `"My decision"` and directly, unambiguously names every requested action. The
  capitalization and both ASCII double-quote characters are part of the
  required prefix. Only the actions explicitly named in that instruction are
  authorized; for example, `"My decision" commit and push` authorizes both the
  commit and the push, while `"My decision" commit` does not authorize a push.
  Unless the instruction explicitly narrows the candidate, the candidate is
  the complete current tracked/untracked working tree. "Ready to commit"
  without the exact quoted prefix `"My decision"` authorizes review and
  validation only, not staging or committing. Final evidence is written from
  the complete tracked/untracked working tree. Pre-commit requires the eventual
  staged candidate to match the validated path/hash manifest exactly; a subset
  needs its own validation, and any later candidate edit invalidates the
  evidence. Validation never stages, commits, or pushes automatically.

## What you do **not** have to do

- Do **not** rename `architecture-documentation.md` to `AGENTS.md` — it serves a different purpose and is firmly anchored in rules, hooks, and skills.
- Do not create a second, parallel architecture doc; `architecture-documentation.md` is the canonical reference.
