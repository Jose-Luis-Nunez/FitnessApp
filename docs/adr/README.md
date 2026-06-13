# Architectural Decision Records (ADRs)

This directory holds the project's architectural decisions in the [MADR](https://adr.github.io/madr/) format.

> **New to the team?** Start with [ONBOARDING.md](ONBOARDING.md) — 5 minutes,
> covers ADR workflow, pre-commit hooks, and current decisions.

## What is an ADR?

An ADR captures a significant architectural decision: the context, the options considered, the chosen option, and the consequences. ADRs are immutable once accepted — they are superseded by new ADRs, never edited in-place.

## When to write an ADR

- Any change that touches multiple packages
- Any change that introduces or removes a layer (UI / Domain / Persistence)
- Any change to a SwiftUI observation/state-management pattern that applies project-wide
- Any decision that future contributors must respect (e.g. "always use X for Y")
- Any decision that resolves a long-standing tension between two refactor approaches

If the decision affects only one file or one feature, prefer a code comment instead.

## Template

Use the MADR template:

```markdown
# NNNN — Title

* Status: proposed | accepted | superseded by ADR-XXXX
* Date: YYYY-MM-DD
* Deciders: <name(s)>

## Context

What problem are we solving? What constraints exist? What evidence (bugs, reviews, prior refactors) drives the need for a decision?

## Options

- **A**: …
- **B**: …
- **C**: …

## Decision

Which option, and why. Be explicit about scope and non-goals.

## Consequences

Positive, negative, neutral.

## References

Cross-links to other ADRs, plans, code, external resources.
```

## Index

| ID | Title | Status |
|----|-------|--------|
| 0001 | @Model als UI Single Source of Truth | accepted |
| 0002 | FitnessPersistenceUI Package | accepted |
| 0003 | Coordinator Session-State Vertrag | accepted |
| 0004 | _(reserved — CloudKit / TCA migration trigger)_ | reserved |
| 0005 | SwiftData Schema-Migration-Strategie (VersionedSchema + MigrationPlan) | accepted |
| 0006 | Versionierte Git-Hooks via `core.hooksPath` | accepted |
| 0007 | SessionTrainingCache entfernen, ResetAllExercisesUseCase auf TrainingCoordinatorCache umstellen | accepted |
| 0008 | Friends Comparison: isolated JSON-blob storage + dedicated module | accepted |

> **ADR-0004 Hinweis:** Die Nummer 0004 ist bewusst nicht vergeben. Zwei bestehende ADRs verweisen auf "ADR-0004" als zukünftigen Anker für zwei mögliche Trigger:
> - **TCA-Migration** (referenziert in ADR-0001 §"Trigger eingetreten → ADR-0004 schreiben"): Wenn die Observability-Probleme von SwiftUI/SwiftData unhaltbar werden, würde ADR-0004 die Migration zu The Composable Architecture dokumentieren.
> - **CloudKit-Sync** (referenziert in ADR-0005 §Consequences): Wenn die App über das lokale Single-User-Modell hinausgeht, würde ADR-0004 die CloudKit-Integrationsstrategie festhalten.
>
> Die Nummer wird offen gehalten bis einer dieser Trigger einsetzt — kein "skipped", sondern aktiv reserviert.

## Enforcement

The stop-hook check `.cursor/hooks/checks/adr-required.sh` (added in T0d of the
`observable-models-sot` plan) detects structural changes that should have an ADR
and reminds the agent to either add a new ADR or update an existing one.
