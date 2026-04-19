# T0d — ADR-Bypass Hook

> **Layer**: Agent-System Härtung
> **Vorbedingung**: keine
> **Blockiert**: T1 (ADRs), T0a-T0e bleiben unabhängig
> **Aufwand**: ~30 min

## Ziel

Strukturelle Architektur-Änderungen (neue cross-cutting Sync-Mechanismen, neue
Cross-Layer-Observation-Patterns, neue State-Holders) blockieren wenn kein ADR
im selben Commit/PR vorhanden ist.

## Was triggert die ADR-Pflicht

Trigger-Patterns (jeder einzelne genügt):

1. Neue `@Observable` Klasse die mehr als ein anderes Modul observed
2. Neue `withObservationTracking { ... } onChange:` außerhalb von SwiftUI Views
3. Neue `Task { while !Task.isCancelled { ... } }` in einem `*Service.swift` oder `*ViewModel.swift`
4. Schema-Änderungen an `@Model` Klassen (neue Properties, geänderte Relationships)
5. Neues SPM-Package in `Packages/` (neuer `Package.swift`)
6. Änderungen an `Container.swift` (Factory-Wiring)

## Schritte

### 1. Neuen Hook-Check anlegen

`Datei: .cursor/hooks/checks/adr-required.sh`

```bash
#!/usr/bin/env bash
# T0d: Erzwingt ADR bei strukturellen Architektur-Änderungen.
# Exit 0 = OK, exit 1 = blockiert.

set -uo pipefail

cd "$(git rev-parse --show-toplevel)" || exit 0

DIFF=$(git diff --cached --diff-filter=AM 2>/dev/null) || DIFF=""
DIFF_FILES=$(git diff --cached --diff-filter=AM --name-only 2>/dev/null) || DIFF_FILES=""
[ -z "$DIFF" ] && exit 0

triggers=()

# Trigger 1: neue @Observable im Service-Layer
if echo "$DIFF" | rg -q '^\+.*@Observable' && echo "$DIFF_FILES" | rg -q '/Sources/.*Service\.swift$'; then
    triggers+=("new-observable-in-service")
fi

# Trigger 2: withObservationTracking außerhalb View
if echo "$DIFF" | rg -q '^\+.*withObservationTracking' && ! echo "$DIFF_FILES" | rg -q 'View\.swift$'; then
    triggers+=("observation-tracking-outside-view")
fi

# Trigger 3: while !Task.isCancelled in Service oder ViewModel
if echo "$DIFF" | rg -q '^\+.*while\s+!Task\.isCancelled' \
   && echo "$DIFF_FILES" | rg -q '(Service|ViewModel)\.swift$'; then
    triggers+=("polling-loop-in-service-or-vm")
fi

# Trigger 4: @Model Property-Änderung
if echo "$DIFF" | rg -q '^\+\s*(@Attribute|@Relationship)' \
   && echo "$DIFF_FILES" | rg -q '/Models/.*\.swift$'; then
    triggers+=("schema-change")
fi

# Trigger 5: neues Package
if echo "$DIFF_FILES" | rg -q '^Packages/[^/]+/Package\.swift$' \
   && echo "$DIFF" | rg -q '^\+.*name:\s*"'; then
    triggers+=("new-package")
fi

# Trigger 6: Container.swift change
if echo "$DIFF_FILES" | rg -q 'Container\.swift$'; then
    triggers+=("container-change")
fi

[ ${#triggers[@]} -eq 0 ] && exit 0

# Check for ADR in same diff
adr_added=$(echo "$DIFF_FILES" | rg -c '^docs/adr/.*\.md$' || true)

# OR exception stamp
stamp=".cursor/hooks/state/adr-exception.stamp.md"
stamp_fresh=0
if [ -f "$stamp" ] && [ $(( $(date +%s) - $(stat -f %m "$stamp") )) -lt 86400 ]; then
    stamp_fresh=1
fi

if [ "${adr_added:-0}" -eq 0 ] && [ "$stamp_fresh" -eq 0 ]; then
    cat <<EOF
RULE: T0d adr-required.sh — strukturelle Architektur-Änderung erkannt.
VIOLATION: Trigger(s): ${triggers[*]}
FIX:
  - Schreibe ADR in docs/adr/NNNN-titel.md (Format siehe docs/adr/README.md), oder
  - Bei trivialer Änderung: stamp .cursor/hooks/state/adr-exception.stamp.md mit Begründung
EOF
    exit 1
fi
exit 0
```

`chmod +x .cursor/hooks/checks/adr-required.sh`

### 2. Hook in post-task-check integrieren

`Datei: .cursor/hooks/post-task-check.sh` — neuen Check-Aufruf einbauen (analog
zu existierenden `code-validation.sh`):

```bash
# T0d: ADR required for structural changes
if [ -x ".cursor/hooks/checks/adr-required.sh" ]; then
    .cursor/hooks/checks/adr-required.sh || exit 1
fi
```

### 3. Pre-commit Hook ergänzen

`Datei: .git/hooks/pre-commit` — neuer Check (nicht versioniert, in Setup-Doc beschreiben):

```bash
# T0d ADR check
if [ -x .cursor/hooks/checks/adr-required.sh ]; then
    .cursor/hooks/checks/adr-required.sh || {
        echo "Pre-commit blocked by adr-required.sh (T0d)"
        exit 1
    }
fi
```

### 4. ADR-README

`Datei: docs/adr/README.md`

```markdown
# Architectural Decision Records

Format: MADR (Markdown Architectural Decision Records)
https://adr.github.io/madr/

## Naming

`docs/adr/NNNN-kebab-case-titel.md` (4-stellige Nummer fortlaufend ab 0001)

## Template

\`\`\`markdown
# NNNN — Titel

* Status: proposed | accepted | deprecated | superseded by NNNN
* Date: YYYY-MM-DD
* Deciders: <Namen>

## Kontext

Was ist das Problem? Welche Kräfte wirken?

## Optionen

- Option A — beschrieben
- Option B — beschrieben

## Entscheidung

Wir wählen Option X weil ...

## Konsequenzen

- Positiv: ...
- Negativ: ...
- Neutral: ...

## Verweise

- Verwandte ADRs
- Externe Quellen
\`\`\`

## ADRs in diesem Repo

| Nr | Titel | Status |
|----|-------|--------|
| 0001 | (kommt mit T1) | |
```

## Definition of Done

- [ ] `.cursor/hooks/checks/adr-required.sh` existiert, executable, mit allen 6 Triggern
- [ ] In `post-task-check.sh` und `.git/hooks/pre-commit` aufgerufen
- [ ] `docs/adr/README.md` mit Template existiert
- [ ] Manuell getestet: synthetischer Diff mit `@Observable` in `XService.swift` ohne ADR wird geblockt
- [ ] Manuell getestet: derselbe Diff MIT neuem `docs/adr/0001-test.md` passiert durch
- [ ] Commit-Message verweist auf T0d + Plan

## Akzeptanzkriterien

Strukturelle Änderungen können nicht mehr ohne ADR commited werden. Ein Refactor 4
das z.B. einen neuen Sync-Mechanismus einführt wird beim Commit-Versuch geblockt.
