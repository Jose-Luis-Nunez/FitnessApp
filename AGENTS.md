# FitnessApp — Hinweise für Agenten

Kurzer Einstieg; Details stehen in den versionierten Cursor-Dateien.

## Konventionen und Architektur

- **Projektregeln (verbindlich):** `.cursor/rules/` — u. a. Swift-Architektur, AppStyle, Docs-Sync, Self-Improvement.
- **Struktur-Inventar (Feature Map, Services, Models, Navigation, Shared Components):** `.cursor/references/architecture.md` — bei strukturellen Swift-/Design-Änderungen **mitpflegen** (Trigger siehe Rule `docs-sync.mdc`).
- **Workflows:** `.cursor/skills/` (SKILL.md pro Skill), Subagents unter `.cursor/agents/`.

`architecture.md` ist **kein** Ersatz für die Rules: Es dokumentiert die **Ist-Struktur**; Vorgaben stehen in den `.mdc`-Rules.

## Build und Tests (Xcode)

- Projekt öffnen: `FitnessApp.xcodeproj`
- Scheme: **FitnessApp** (geteilt unter `FitnessApp.xcodeproj/xcshareddata/xcschemes/`)

Beispiel über die Kommandozeile (Simulator anpassen, falls nötig):

```bash
xcodebuild -scheme FitnessApp -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -scheme FitnessApp -destination 'platform=iOS Simulator,name=iPhone 16' test
```

## Was ihr **nicht** tun müsst

- `architecture.md` **nicht** in `AGENTS.md` umbenennen — anderer Zweck und fest in Rules, Hooks und Skills verankert.
- Keine zweite, parallele Architektur-Doku anlegen; `architecture.md` ist die kanonische Referenz.
