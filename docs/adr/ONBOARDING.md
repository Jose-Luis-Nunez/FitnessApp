# ADR Onboarding

This page explains in 5 minutes how we document, enforce, and change
architectural decisions in the FitnessApp. Read it once
during onboarding and keep it as a reference.

## What is an ADR?

An **Architectural Decision Record** is a short, dated Markdown document
under `docs/adr/NNNN-slug.md` that captures a decision **along with its rejected
alternatives** and **consequences**. ADRs are **immutable** once accepted —
changed decisions are replaced by a new ADR
(`Status: superseded by ADR-XXXX`), never edited in place.

Format: [MADR](https://adr.github.io/madr/). Template in `docs/adr/README.md`.

## Initial Setup after the clone

Run exactly once per clone:

```bash
./scripts/install-hooks.sh
```

This activates the versioned pre-commit hooks (see ADR-0006). Without
this step you are missing all architecture-protection checks.

Verify:

```bash
git config --get core.hooksPath
# Expected: .githooks
```

## When do I have to write an ADR?

Required (enforced by the pre-commit hook `adr-required.sh`):

- The change touches more than one package
- A new layer / module (e.g. a new `Fitness*` package)
- A new SwiftData schema or migration (see ADR-0005)
- A change to a project-wide SwiftUI observation/state pattern
- A decision that future contributors must respect

Not necessary:

- A bug fix in an isolated view
- A refactor within a single file
- A style-token swap (`AppStyle.X → AppStyle.Y`)

If the hook fires incorrectly (e.g. a large refactor with a clear template
in an existing ADR): a one-time exception via
`touch .cursor/hooks/state/adr-exception.stamp.md` with a rationale in the
commit body. Valid for 24 h.

## How do I write an ADR?

1. **Pick a number**: the next free number in `docs/adr/`.
2. **Copy the template**: from `docs/adr/README.md`.
3. **Evaluate the options honestly**: at least 2 alternatives + why rejected.
   Do not just document the desired solution.
4. **List the consequences**: positive, negative, neutral.
5. **Update the index**: the table in `docs/adr/README.md`.
6. **Commit**: commit the ADR file + index update together. Mention the
   ADR number in the commit body (`per ADR-NNNN`) so that `adr-required.sh` is happy.

## How do I change an existing ADR?

You don't. Instead of editing:

1. Write a new ADR `NNNN+1-slug.md` with the new decision.
2. In the header of the new ADR: `Supersedes ADR-NNNN`.
3. In the header of the old ADR: `Status: superseded by ADR-NNNN+1` (this is the
   only allowed in-place change).
4. Update the index.

This keeps the decision history traceable — everyone can read
**why** we decided differently before.

## Current ADRs (as of 2026-04-19)

| ID | Title | What it prescribes for you |
|----|-------|------------------------|
| 0001 | `@Model` as UI Single Source of Truth | The UI reads directly from `@Model` via `@Query`/`@Bindable`. No `Exercise` struct snapshot in `@State`. |
| 0002 | `FitnessPersistenceUI` Package | `import SwiftData` + `@Query` exclusively in `FitnessPersistenceUI`. Other packages use domain structs. |
| 0003 | Coordinator session-state contract | `TrainingCoordinator` state is non-persistent + blocks edits during an active session. |
| 0005 | SwiftData schema migration | Every schema change goes through `Schema/SchemaVN.swift` + `Schema/MigrationPlan.swift`. Custom stages MUST be tested. |
| 0006 | Versioned Git hooks | Hooks live in `.githooks/`, activated via `scripts/install-hooks.sh`. |

Full list + latest: `docs/adr/README.md`.

## Pre-commit hook checks (what blocks your commit?)

The hook (`/.githooks/pre-commit`) checks five things in this order:

1. **Validation stamp**: with 1+ Swift files a fresh
   `.cursor/hooks/state/code-changes.stamp.md` (< 30 min old) must exist.
   → Run the `reviewing-code-changes` skill or
     `touch .cursor/hooks/state/code-changes.stamp.md` after a manual check.
2. **No `print()`** in production Swift. → `Logger` instead of `print()`.
3. **ADR obligation** on structural triggers (see above).
4. **UI state sync anti-pattern** (Int counter + polling loop). →
   Use ADR-0001, no own counter sync.
5. **`architecture-documentation.md` freshness** on new features /
   services / use cases / shared components.

On errors the hook delivers RULE/VIOLATION/FIX-formatted messages — the
line with `FIX:` contains the repair path.

Emergency bypass: `git commit --no-verify`. Only in exceptional cases; document
the reason in the commit body. Code review will ask.

## Where do I find what?

| What | Where |
|------|-----|
| ADR index + template | `docs/adr/README.md` |
| Individual ADRs | `docs/adr/NNNN-*.md` |
| Hook scripts | `.githooks/` (versioned), `.cursor/hooks/checks/` (Stop hooks) |
| Cursor rules | `.cursor/rules/*.mdc` |
| Cursor skills (workflows) | `.cursor/skills/<name>/SKILL.md` |
| Current architecture state | `.cursor/references/architecture-documentation.md` |
| Migration plans | `.cursor/plans/<plan>/` |

## Help

- ADR unclear? → ask in the team chat, no one has to guess.
- Hook blocking? → read the `FIX:` line, that is usually the answer.
- Something in an ADR contradicts reality? → write a new ADR (see
  "How do I change an existing ADR?"). Do not deviate silently.
