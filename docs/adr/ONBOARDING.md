# ADR-Onboarding

Diese Seite erklärt in 5 Minuten, wie wir architektonische Entscheidungen
in der FitnessApp dokumentieren, durchsetzen und ändern. Lies sie einmal
beim Onboarding und behalte sie als Nachschlagewerk.

## Was ist eine ADR?

Eine **Architectural Decision Record** ist ein kurzes, datiertes Markdown-Dokument
unter `docs/adr/NNNN-slug.md`, das eine Entscheidung **mit ihren verworfenen
Alternativen** und **Konsequenzen** festhält. ADRs sind nach Annahme **immutable** —
geänderte Entscheidungen werden durch eine neue ADR ersetzt
(`Status: superseded by ADR-XXXX`), niemals in-place editiert.

Format: [MADR](https://adr.github.io/madr/). Vorlage in `docs/adr/README.md`.

## Erste Schritte nach dem Clone

Genau einmal pro Clone ausführen:

```bash
./scripts/install-hooks.sh
```

Das aktiviert die versionierten Pre-Commit-Hooks (siehe ADR-0006). Ohne
diesen Schritt fehlen dir alle Architektur-Schutz-Checks.

Verifiziere:

```bash
git config --get core.hooksPath
# Erwartet: .githooks
```

## Wann muss ich eine ADR schreiben?

Pflicht (durchgesetzt vom Pre-Commit-Hook `adr-required.sh`):

- Änderung berührt mehr als ein Package
- Neue Layer / Modul (z. B. neues `Fitness*`-Package)
- Neues SwiftData-Schema oder Migration (siehe ADR-0005)
- Änderung an einem projektweiten SwiftUI-Observation-/State-Pattern
- Entscheidung, die zukünftige Contributors respektieren müssen

Nicht nötig:

- Bug-Fix in einem isolierten View
- Refactor innerhalb eines Files
- Style-Token-Tausch (`AppStyle.X → AppStyle.Y`)

Wenn der Hook fälschlich auslöst (z. B. großes Refactor mit klarer Vorlage
in einer existierenden ADR): einmalige Ausnahme via
`touch .cursor/hooks/state/adr-exception.stamp.md` mit Begründung im
Commit-Body. Gilt 24 h.

## Wie schreibe ich eine ADR?

1. **Nummer wählen**: nächste freie Zahl in `docs/adr/`.
2. **Vorlage kopieren**: aus `docs/adr/README.md`.
3. **Optionen ehrlich evaluieren**: mindestens 2 Alternativen + warum verworfen.
   Nicht bloß die Wunschlösung dokumentieren.
4. **Konsequenzen aufzählen**: positive, negative, neutrale.
5. **Index aktualisieren**: Tabelle in `docs/adr/README.md`.
6. **Commit**: ADR-Datei + Index-Update zusammen committen. Im Commit-Body die
   ADR-Nummer erwähnen (`per ADR-NNNN`), damit `adr-required.sh` glücklich ist.

## Wie ändere ich eine bestehende ADR?

Gar nicht. Statt zu editieren:

1. Neue ADR `NNNN+1-slug.md` schreiben mit der neuen Entscheidung.
2. Im Header der neuen ADR: `Supersedes ADR-NNNN`.
3. Im Header der alten ADR: `Status: superseded by ADR-NNNN+1` (das ist die
   einzige erlaubte In-Place-Änderung).
4. Index aktualisieren.

Damit bleibt die Entscheidungs-Historie nachvollziehbar — jeder kann lesen
**warum** wir früher anders entschieden haben.

## Aktuelle ADRs (Stand 2026-04-19)

| ID | Titel | Was es dir vorschreibt |
|----|-------|------------------------|
| 0001 | `@Model` als UI Single Source of Truth | UI liest direkt aus `@Model` via `@Query`/`@Bindable`. Kein `Exercise`-struct-Snapshot in `@State`. |
| 0002 | `FitnessPersistenceUI` Package | `import SwiftData` + `@Query` ausschließlich in `FitnessPersistenceUI`. Andere Packages nutzen Domain-Structs. |
| 0003 | Coordinator Session-State Vertrag | `TrainingCoordinator`-State ist non-persistent + blockiert Edits während aktiver Session. |
| 0005 | SwiftData Schema-Migration | Jeder Schema-Change geht über `Schema/SchemaVN.swift` + `Schema/MigrationPlan.swift`. Custom Stages MÜSSEN getestet sein. |
| 0006 | Versionierte Git-Hooks | Hooks leben in `.githooks/`, aktiviert via `scripts/install-hooks.sh`. |

Volle Liste + neueste: `docs/adr/README.md`.

## Pre-Commit-Hook-Checks (was blockiert deinen Commit?)

Der Hook (`/.githooks/pre-commit`) prüft fünf Dinge in dieser Reihenfolge:

1. **Validation-Stamp**: Bei 1+ Swift-Files muss ein frischer
   `.cursor/hooks/state/code-changes.stamp.md` (< 30 min alt) existieren.
   → Skill `reviewing-code-changes` durchlaufen oder
     `touch .cursor/hooks/state/code-changes.stamp.md` nach manueller Prüfung.
2. **Kein `print()`** in Production-Swift. → `Logger` statt `print()`.
3. **ADR-Pflicht** bei strukturellen Triggers (siehe oben).
4. **UI-State-Sync-Anti-Pattern** (Int-Counter + Polling-Loop). →
   ADR-0001 nutzen, kein eigenes Counter-Sync.
5. **`architecture-documentation.md`-Aktualität** bei neuen Features /
   Services / Use Cases / Shared Components.

Bei Fehlern liefert der Hook RULE/VIOLATION/FIX-formatierte Meldungen — die
Zeile mit `FIX:` enthält den Reparaturweg.

Notfall-Bypass: `git commit --no-verify`. Nur in Ausnahmefällen, dokumentiere
den Grund im Commit-Body. Code-Review wird nachfragen.

## Wo finde ich was?

| Was | Wo |
|------|-----|
| ADR-Index + Vorlage | `docs/adr/README.md` |
| Einzelne ADRs | `docs/adr/NNNN-*.md` |
| Hook-Skripte | `.githooks/` (versioniert), `.cursor/hooks/checks/` (Stop-Hooks) |
| Cursor-Rules | `.cursor/rules/*.mdc` |
| Cursor-Skills (Workflows) | `.cursor/skills/<name>/SKILL.md` |
| Architektur-Ist-Stand | `.cursor/references/architecture-documentation.md` |
| Migrations-Pläne | `.cursor/plans/<plan>/` |

## Hilfe

- ADR unklar? → frag im Team-Chat, niemand muss raten.
- Hook blockiert? → lies die `FIX:`-Zeile, das ist meistens die Antwort.
- Etwas in einer ADR widerspricht der Realität? → neue ADR schreiben (siehe
  „Wie ändere ich eine bestehende ADR?"). Nicht stillschweigend abweichen.
