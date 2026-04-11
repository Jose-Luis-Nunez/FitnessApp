# Agent Workflow Enforcement — Visualisierung

## 1. Das Problem: Warum Rules nicht reichen

```
                    CONTEXT WINDOW
    ┌─────────────────────────────────────────┐
    │                                         │
    │  ┌─────────────────────────────────┐    │
    │  │     TASK CONTEXT (aktuell)      │    │  ◄── Höchste Aufmerksamkeit
    │  │  "Refactor TrainingCoordinator  │    │
    │  │   into Use Cases..."            │    │
    │  └─────────────────────────────────┘    │
    │                                         │
    │  ┌─────────────────────────────────┐    │
    │  │     CONVERSATION HISTORY        │    │  ◄── Mittlere Aufmerksamkeit
    │  │  User: "erstelle Use Cases"     │    │
    │  │  Agent: "Ich erstelle 5..."     │    │
    │  └─────────────────────────────────┘    │
    │                                         │
    │  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐    │
    │    RULES (system prompt)               │  ◄── NIEDRIGSTE Aufmerksamkeit
    │  │ "you MUST validate..."          │    │      "dropped first under
    │    "you MUST update docs..."           │       context pressure"
    │  │ "you MUST run tests..."         │    │
    │   ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─    │
    └─────────────────────────────────────────┘

    Je voller das Context Window, desto eher
    werden Rules ignoriert: ~70-85% Compliance
```

## 2. Die Enforcement Ladder

```
    ZUVERLÄSSIGKEIT
         ▲
    100% │  ████████████████████  L5: HOOKS (stop, PreToolUse)
         │  ████████████████████       "Physically prevented"
         │  ████████████████████       Deterministisch, System-Level
         │
     95% │  ██████████████████    L4: TESTS & CI GATES
         │  ██████████████████         Pre-Commit, GitHub Actions
         │  ██████████████████         "Blockiert bei Merge"
         │
     90% │  ████████████████      L3: TEMPLATES & COMMANDS
         │  ████████████████           Skills, Custom Commands
         │  ████████████████           "Richtiger Pfad = einfacher Pfad"
         │
     80% │  ██████████████        L2: PROSE DOCS  ◄── WIR WAREN HIER
         │  ██████████████             .cursor/rules/, CLAUDE.md
         │  ██████████████             "you MUST..." — degradiert über Zeit
         │
     50% │  ████████████          L1: CONVERSATION
         │  ████████████               "Vergiss nicht zu validieren"
         │  ████████████               Vergessen nach 2-3 Turns
         │
      0% ┼──────────────────────────────────────────►
              ENFORCEMENT STUFE

    ┌──────────────────────────────────────────────┐
    │  PRINZIP: Wenn eine Regel auf Stufe N        │
    │  wiederholt ignoriert wird, gehört sie        │
    │  auf Stufe N+1.                              │
    │                                              │
    │  "auto-validation.mdc" war L2 → gehört L5   │
    └──────────────────────────────────────────────┘
```

## 3. Defense-in-Depth: Der "Bowling Bumper" Stack

```
    AGENT ARBEITET
         │
         ▼
    ┌─────────────────────────────────────────────────────────┐
    │  LAYER 1: RULES (.mdc)                                  │
    │  ┌───────────────────────────────────────────────────┐  │
    │  │ auto-validation.mdc: "Wenn du Swift-Dateien       │  │
    │  │ änderst, starte den post-change-validator."       │  │
    │  │                                                   │  │
    │  │ Compliance: ~80%                                  │  │
    │  │ Fängt: Die meisten Fälle wo der Agent aufmerksam  │  │
    │  │        ist und die Rule liest                     │  │
    │  └───────────────────────────────────────────────────┘  │
    │         │ Agent ignoriert Rule?                          │
    │         ▼                                               │
    │  LAYER 2: STOP HOOK (Grind Loop)                        │
    │  ┌───────────────────────────────────────────────────┐  │
    │  │                                                   │  │
    │  │  Agent sagt "fertig"                              │  │
    │  │       │                                           │  │
    │  │       ▼                                           │  │
    │  │  ┌──────────────┐    ┌──────────────────────┐     │  │
    │  │  │ stop-Hook    │───►│ git diff: Swift?     │     │  │
    │  │  │ feuert       │    │ Validation-Artefakt? │     │  │
    │  │  └──────────────┘    └──────────┬───────────┘     │  │
    │  │                           │           │           │  │
    │  │                        JA, fehlt    NEIN, ok      │  │
    │  │                           │           │           │  │
    │  │                           ▼           ▼           │  │
    │  │                    followup_msg    {} (pass)      │  │
    │  │                    "Iteration 2/5                 │  │
    │  │                     Validate now!"                │  │
    │  │                                                   │  │
    │  │  Compliance: ~100% (Agent wird zurückgeschickt)   │  │
    │  │  Fängt: Alle Fälle wo Rule ignoriert wurde       │  │
    │  └───────────────────────────────────────────────────┘  │
    │         │ Agent ignoriert followup_message?              │
    │         │ (selten, aber möglich)                         │
    │         ▼                                               │
    │  LAYER 3: PRE-COMMIT HOOK                               │
    │  ┌───────────────────────────────────────────────────┐  │
    │  │                                                   │  │
    │  │  Agent versucht zu committen                      │  │
    │  │       │                                           │  │
    │  │       ▼                                           │  │
    │  │  ┌──────────────────────────────────────────┐     │  │
    │  │  │ RULE: Post-change validation required.   │     │  │
    │  │  │ VIOLATION: 5 Swift files changed,        │     │  │
    │  │  │   no validation-stamp.md found.          │     │  │
    │  │  │ FIX: Run post-change-validation skill.   │     │  │
    │  │  │ FILES: TrainingCoordinator.swift, ...     │     │  │
    │  │  └──────────────────────────────────────────┘     │  │
    │  │       │                                           │  │
    │  │       ▼                                           │  │
    │  │  Agent liest Error → korrigiert sich selbst       │  │
    │  │                                                   │  │
    │  │  Compliance: 100% (Commit wird blockiert)         │  │
    │  │  Fängt: Alles was Hooks durchgelassen haben       │  │
    │  └───────────────────────────────────────────────────┘  │
    │         │ Agent committed nicht (arbeitet ohne commit)? │
    │         ▼                                               │
    │  LAYER 4: CI/CD PIPELINE                                │
    │  ┌───────────────────────────────────────────────────┐  │
    │  │                                                   │  │
    │  │  PR wird erstellt → GitHub Action läuft:          │  │
    │  │  • swift test                                     │  │
    │  │  • swiftlint                                      │  │
    │  │  • architecture.md freshness check                │  │
    │  │                                                   │  │
    │  │  Compliance: 100% (Merge wird blockiert)          │  │
    │  │  Fängt: ALLES — Agent-unabhängig                  │  │
    │  └───────────────────────────────────────────────────┘  │
    │         │                                               │
    │         ▼                                               │
    │  LAYER 5: HUMAN REVIEW                                  │
    │  ┌───────────────────────────────────────────────────┐  │
    │  │  Plan Mode Review, Commit-Checkpoints, Rollback   │  │
    │  └───────────────────────────────────────────────────┘  │
    └─────────────────────────────────────────────────────────┘

    Jede Schicht fängt was die vorherige durchlässt.
    Keine einzelne Schicht muss perfekt sein.
```

## 4. Der Grind Loop im Detail

```
    AGENT ARBEITET AN TASK
         │
         │  ... ändert 5 Swift-Dateien ...
         │  ... vergisst Validation ...
         │
         ▼
    ┌──────────┐
    │  "Fertig" │
    └─────┬────┘
          │
          ▼
    ╔══════════════════════════════════════════╗
    ║  STOP HOOK FEUERT                        ║
    ║                                          ║
    ║  1. Liest Scratchpad:                    ║
    ║     .cursor/hooks/state/scratchpad.md    ║
    ║                                          ║
    ║  2. Prüft:                               ║
    ║     ┌─────────────────────────┐          ║
    ║     │ git diff: Swift-Dateien │          ║
    ║     │ geändert?               │          ║
    ║     └───────────┬─────────────┘          ║
    ║            JA    │                       ║
    ║                  ▼                       ║
    ║     ┌─────────────────────────┐          ║
    ║     │ validation-stamp.md     │          ║
    ║     │ existiert & aktuell?    │          ║
    ║     └───────────┬─────────────┘          ║
    ║            NEIN  │                       ║
    ║                  ▼                       ║
    ║     ┌─────────────────────────┐          ║
    ║     │ Iteration < 5?          │          ║
    ║     └───────────┬─────────────┘          ║
    ║            JA    │                       ║
    ║                  ▼                       ║
    ║  3. Schreibt ins Scratchpad:             ║
    ║     iteration: 2                         ║
    ║     status: validation_pending           ║
    ║                                          ║
    ║  4. Sendet followup_message:             ║
    ║     "[Iteration 2/5] 5 Swift files       ║
    ║      changed. No validation report       ║
    ║      found. Run post-change-validation   ║
    ║      skill now."                         ║
    ╚══════════════╤═══════════════════════════╝
                   │
                   ▼
          ┌────────────────┐
          │ Agent wird     │
          │ zurückgeschickt│
          │ und validiert  │
          └────────┬───────┘
                   │
                   │  ... erstellt validation-stamp.md ...
                   │
                   ▼
          ┌──────────┐
          │  "Fertig" │
          └─────┬────┘
                │
                ▼
    ╔══════════════════════════════════════════╗
    ║  STOP HOOK FEUERT (Iteration 2)          ║
    ║                                          ║
    ║  1. Liest Scratchpad: iteration=2        ║
    ║  2. Prüft: validation-stamp.md?           ║
    ║     → JA, existiert!                     ║
    ║  3. Schreibt: status=DONE                ║
    ║  4. Gibt {} zurück                       ║
    ║                                          ║
    ║  ✓ Agent darf aufhören                   ║
    ╚══════════════════════════════════════════╝
```

## 5. Cursor vs. Claude Code: Feature-Vergleich

```
    ENFORCEMENT FEATURE          CURSOR              CLAUDE CODE
    ─────────────────────────────────────────────────────────────

    Hook Events                  6                   21+
                                 ▓▓░░░░░░░░          ▓▓▓▓▓▓▓▓▓▓

    Stop-Hook Semantik           followup_message     decision: "block"
                                 (Bitte)              (Blockade)
                                 ▓▓▓▓▓░░░░░          ▓▓▓▓▓▓▓▓▓▓

    Session State                Keiner (extern)      stop_hook_active
                                 ▓▓░░░░░░░░          ▓▓▓▓▓▓▓░░░

    Tool-Call Blocking           beforeShell nur      PreToolUse deny
                                 ▓▓▓▓░░░░░░          ▓▓▓▓▓▓▓▓▓▓

    Handler Types                command only         command, HTTP,
                                 ▓▓▓░░░░░░░          prompt, agent
                                                     ▓▓▓▓▓▓▓▓▓▓

    Subagent Hooks               Nein                 Teilweise
                                 ░░░░░░░░░░          ▓▓▓▓▓░░░░░

    Cloud/Background             Nein                 Ja
                                 ░░░░░░░░░░          ▓▓▓▓▓▓▓▓▓▓

    ─────────────────────────────────────────────────────────────

    CURSOR:       ▓▓▓░░░░░░░   Enforcement möglich,
                                aber mit Workarounds

    CLAUDE CODE:  ▓▓▓▓▓▓▓▓░░   Stärkere native
                                Enforcement, weniger Lücken
```

## 6. Was WIR jetzt haben vs. was wir brauchen

```
    VORHER (diese Session)              NACHHER (Ziel)
    ──────────────────────              ──────────────────────

    ┌─────────────────────┐            ┌─────────────────────┐
    │ auto-validation.mdc │            │ auto-validation.mdc │
    │ "you MUST validate" │            │ Dokumentiert den     │
    │                     │            │ Mechanismus, nicht   │
    │ → Agent ignoriert   │            │ "du MUSST"           │
    │   es bei 20% der    │            │                      │
    │   Fälle             │            │ → L2 (Dokumentation) │
    └─────────────────────┘            └─────────────────────┘
                                                │
              ╳                                 ▼
         Keine weitere              ┌─────────────────────┐
         Absicherung                │ stop-Hook            │
                                    │ (Grind Loop)         │
                                    │                      │
                                    │ Scratchpad + Iter.   │
                                    │ → L5 (Enforcement)   │
                                    └─────────────────────┘
                                                │
                                                ▼
                                    ┌─────────────────────┐
                                    │ Pre-Commit Hook      │
                                    │ (AI-optimierte Msgs) │
                                    │                      │
                                    │ RULE/VIOLATION/FIX   │
                                    │ → L4 (Fallback)      │
                                    └─────────────────────┘
                                                │
                                                ▼
                                    ┌─────────────────────┐
                                    │ CI/CD Pipeline       │
                                    │ (GitHub Action)      │
                                    │                      │
                                    │ swift test + lint    │
                                    │ → L4 (letzte Linie)  │
                                    └─────────────────────┘

    "Stop asking your agent to be good.
     Make it structurally impossible to be bad."
```
