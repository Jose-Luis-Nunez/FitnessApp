# T0a — State-Sync Rule + Hook-Check

> **Layer**: Agent-System Härtung
> **Vorbedingung**: keine
> **Blockiert**: T1 (ADRs)
> **Aufwand**: ~30 min

## Ziel

Verhindern dass eine zukünftige Refactor-Welle wieder einen `Int`-Counter (`changeVersion`, `mutationVersion`, `dataGeneration`) als primären UI-Sync-Mechanismus einführt — ohne dass irgendeine Layer "STOP" sagt.

## Smell den wir blockieren wollen

```swift
// ANTI-PATTERN: monotoner Int + Polling-Loop als Domain-Event-Ersatz
@Observable
public final class XService {
    public private(set) var changeVersion: Int = 0  // <-- der Counter
    func save() {
        try? context.save()
        changeVersion &+= 1
    }
}

// In ViewModel:
private func startStorageObservation() {
    Task { [weak self] in
        while !Task.isCancelled {  // <-- der Polling-Loop
            await withCheckedContinuation { c in
                withObservationTracking {
                    _ = self?.service.changeVersion
                } onChange: { c.resume() }
            }
            self?.refreshExercises()
        }
    }
}
```

Das ist **semantisches Polling** mit Observation-Verkleidung. Existierende Rule §13b verbietet nur `Task.sleep`-Polling — das fängt diesen Pattern nicht.

## Schritte

### 1. Neue Rule erstellen

`Datei: .cursor/rules/ui-state-sync-enforcement.mdc` (ursprünglich `state-sync.mdc`, umbenannt)

Inhalt:

```markdown
---
description: Verhindert Anti-Pattern beim Cross-Layer State-Sync (monotoner Int-Counter + Polling-Loop als Domain-Event-Ersatz)
alwaysApply: true
---

# State-Sync Anti-Patterns

## Verboten

UI-Refresh darf nicht primär von einem **monotonen Int-Counter** (`changeVersion`,
`mutationVersion`, `dataGeneration`, `revision`) abhängen, der von einem
`while !Task.isCancelled`-Loop mit `withObservationTracking` beobachtet wird.

Das ist semantisches Polling mit Observation-Verkleidung. Es:
- maskiert Save-Failures (kein Save = kein Bump = stale UI ohne Fehlermeldung)
- ersetzt **keine** Domain-Events (was hat sich geändert? warum?)
- führt zu O(N) parallelen Observation-Tasks bei vielen ViewModels

## Erlaubt (gleiches Resultat, sauberer)

- `@Observable`-Klasse mit fachlichen Properties die direkt observed werden
- `@Query` direkt in der View auf `@Model`-Klassen (SwiftData)
- Konkrete Domain-Events via `AsyncSequence` / `NotificationCenter` mit Payload
- `@Bindable` auf `@Model`-Instanzen (UI sieht Mutations sofort)

## Ausnahmen

Nur erlaubt für:
- Debug-Telemetrie (z.B. "wie oft wurde gesaved?")
- Performance-Counters
- Test-Hooks die explizit als solche markiert sind

In allen Fällen: ADR-Pflicht (siehe `ui-state-sync-enforcement.mdc` Hook).

## Hook-Check

Layer 5 (`.cursor/hooks/checks/code-validation.sh`) blockt Diff der **gleichzeitig**:
- ein `Int`-Property mit Namen-Match `(changeVersion|mutationVersion|dataGeneration|revision)` einführt **und**
- ein `while !Task.isCancelled`-Loop mit `withObservationTracking` einführt

Override: Stamp `.cursor/hooks/state/ui-state-sync-exception.stamp.md` mit ADR-Link
(< 24h alt) bestätigt bewusste Ausnahme.
```

### 2. Hook-Check erweitern

`Datei: .cursor/hooks/checks/code-validation.sh` — neue Sektion **am Ende** vor dem `exit`:

```bash
# State-Sync Anti-Pattern Check (T0a)
state_sync_check() {
    local diff_swift
    diff_swift=$(git diff --cached --diff-filter=AM -- '*.swift' 2>/dev/null) || return 0
    [ -z "$diff_swift" ] && return 0

    local has_counter has_loop
    has_counter=$(echo "$diff_swift" | rg -c '^\+.*\b(changeVersion|mutationVersion|dataGeneration|revision)\s*:\s*Int\b' || true)
    has_loop=$(echo "$diff_swift" | rg -c '^\+.*while\s+!Task\.isCancelled' || true)

    if [ "${has_counter:-0}" -gt 0 ] && [ "${has_loop:-0}" -gt 0 ]; then
        # Allow if exception stamp exists and is fresh (<24h)
        local stamp=".cursor/hooks/state/ui-state-sync-exception.stamp.md"
        if [ -f "$stamp" ] && [ $(( $(date +%s) - $(stat -f %m "$stamp") )) -lt 86400 ]; then
            echo "STATE-SYNC: Pattern detected but exception stamp present — allowed."
            return 0
        fi
        cat <<'EOF'
RULE: ui-state-sync-enforcement.mdc — verbietet Int-Counter + Polling-Loop als primären UI-Sync.
VIOLATION: Diff fügt sowohl einen Sync-Counter als auch einen Observation-Polling-Loop hinzu.
FIX:
  - Domain-Events via @Observable Properties oder @Query auf @Model
  - Bei bewusster Ausnahme: ADR schreiben + Stamp `.cursor/hooks/state/ui-state-sync-exception.stamp.md` mit Link
EOF
        return 1
    fi
    return 0
}

state_sync_check || exit 1
```

### 3. Manuelle Verifikation (lokal, nicht im commit)

Erzeuge temporären Diff der das Pattern enthält und stelle sicher dass der Hook BLOCKIERT:

```bash
# In einer Test-Datei kurz hinzufügen:
echo 'public var changeVersion: Int = 0' >> /tmp/dummy.swift
echo 'while !Task.isCancelled { withObservationTracking { } onChange: {} }' >> /tmp/dummy.swift
git add /tmp/dummy.swift  # natürlich revert nach Test
.cursor/hooks/checks/code-validation.sh
# Erwartet: exit 1 mit RULE/VIOLATION/FIX Output
```

## Definition of Done

- [ ] `.cursor/rules/ui-state-sync-enforcement.mdc` existiert mit obigem Inhalt
- [ ] `.cursor/hooks/checks/code-validation.sh` enthält `state_sync_check`-Funktion
- [ ] Manuelle Verifikation: synthetischer Diff mit dem Anti-Pattern wird vom Hook geblockt
- [ ] Commit-Message verweist auf T0a + Plan
- [ ] Stamp `.cursor/hooks/state/code-changes.stamp.md` geschrieben

## Akzeptanzkriterien

Wenn jemand in einem zukünftigen Diff `changeVersion: Int` UND `while !Task.isCancelled { withObservationTracking ... }` einführt, wird der pre-commit-Layer den Commit blockieren mit klarer RULE/VIOLATION/FIX-Message.
