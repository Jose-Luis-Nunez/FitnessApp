# FitnessApp — Hinweise für Agenten

Kurzer Einstieg; Details stehen in den versionierten `.claude/`-Dateien.

## Konventionen und Architektur

- **Projektregeln (verbindlich):** `.claude/rules/` — u. a. Swift-Architektur, AppStyle, Docs-Sync, Build & Test, UI-State-Sync.
- **Struktur-Inventar (Feature Map, Services, Models, Navigation, Shared Components):** `.claude/references/architecture-documentation.md` — bei strukturellen Swift-/Design-Änderungen **mitpflegen** (Trigger siehe Rule `architecture-documentation-sync.mdc` und `reviewing-code-changes` Skill, Sektion "Architecture Sync").
- **Workflows:** `.claude/skills/` (`SKILL.md` pro Skill).
- **Subagents:** `.claude/agents/` (reviewer, tester, verifier — via `Task(subagent_type: "<role>", …)`).
- **Slash-Commands:** `.claude/commands/` (z. B. `/validate`).
- **Hooks:** `.claude/settings.json` registriert `Stop` und `SubagentStop` Hooks; Skripte unter `.claude/hooks/`.

`architecture-documentation.md` ist **kein** Ersatz für die Rules: Es dokumentiert die **Ist-Struktur**; Vorgaben stehen in den `.mdc`-Rules.

## Build und Tests (Xcode)

- Projekt öffnen: `FitnessApp.xcodeproj`
- Scheme: **FitnessApp** (geteilt unter `FitnessApp.xcodeproj/xcshareddata/xcschemes/`)

Beispiel über die Kommandozeile (Simulator anpassen, falls nötig):

```bash
xcodebuild -scheme FitnessApp -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -scheme FitnessApp -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Vollständige Befehle inkl. `DEVELOPER_DIR`-Setup und Package-Tests: siehe `.claude/rules/build-and-test.mdc`.

## Was ihr **nicht** tun müsst

- `architecture-documentation.md` **nicht** in `AGENTS.md` umbenennen — anderer Zweck und fest in Rules, Hooks und Skills verankert.
- Keine zweite, parallele Architektur-Doku anlegen; `architecture-documentation.md` ist die kanonische Referenz.
