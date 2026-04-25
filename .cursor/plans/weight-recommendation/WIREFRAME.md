# Weight Recommendation Feature — Wireframes

> Status: active | Created: 2026-04-24
> Companion: [PLAN.md](PLAN.md), [RESEARCH.md](RESEARCH.md)

## STATE 1 — Idle ohne Empfehlung (heute, unverändert)

User hat < 2 Sessions Historie ODER Service liefert nil.

```
  ┌────────────────────────────────────────────────────────────────┐
  │  ┌──┐  LOL                                            ┌──────┐ │
  │  │ 🏋│                                                 │      │ │
  │  └──┘  Weight  │ Seat │ Progress                      │  ▶   │ │
  │        20 kg   │  +   │   📊  ⌄                       │      │ │
  │                                                       └──────┘ │
  └────────────────────────────────────────────────────────────────┘
```

## STATE 2 — Idle mit Empfehlung  ★ NEU

Service hat einen Vorschlag. Anchor-Delta-Zeile sitzt UNTER metricRow,
NICHT neben dem Play-Button. Ghost-Style, niedrige Sättigung.

```
  ┌────────────────────────────────────────────────────────────────┐
  │  ┌──┐  LOL                                            ┌──────┐ │
  │  │ 🏋│                                                 │      │ │
  │  └──┘  Weight  │ Seat │ Progress                      │  ▶   │ │
  │        20 kg   │  +   │   📊  ⌄                       │      │ │
  │                                                       └──────┘ │
  │  ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄ │
  │  💡  +5 kg · 8 reps   ·   du erhöhst meist um 5         ›     │
  └────────────────────────────────────────────────────────────────┘
       └─ tappable Zeile, Lightbulb in GreenGlow,
          Text white.opacity(0.7), chevron als Affordanz
```

## STATE 3 — Idle expanded (heute, unverändert — Phasen-Tiles)

Tap auf Card öffnet die existierende Phase-Ansicht.
Empfehlungs-Zeile bleibt sichtbar.

```
  ┌────────────────────────────────────────────────────────────────┐
  │  ┌──┐  LOL                                            ┌──────┐ │
  │  │ 🏋│                                                 │      │ │
  │  └──┘  Weight  │ Seat │ Progress                      │  ▶   │ │
  │        20 kg   │  +   │   📊  ⌃                       │      │ │
  │                                                       └──────┘ │
  │  ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄ │
  │  💡  +5 kg · 8 reps   ·   du erhöhst meist um 5         ›     │
  │  ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄ │
  │  Last training: 21.04.26                                       │
  │                                                                │
  │  ┌──────────┐  ┌──────────┐  ┌──────────┐                      │
  │  │ Phase 1  │  │ Phase 2  │  │ Phase 3  │                      │
  │  │ 15→20kg  │  │ 20→25kg  │  │ 25→30kg  │                      │
  │  └──────────┘  └──────────┘  └──────────┘                      │
  └────────────────────────────────────────────────────────────────┘
```

## STATE 4 — Recommendation Detail  ★ NEU (Vollflächen-Modus)

Tap auf 💡-Zeile. Card-Inhalt wird ersetzt: Header + Play bleiben,
metricRow + Phase-Tiles verschwinden, 3 Vorschlags-Tiles erscheinen.
Kein Sheet, keine Modal — gleicher Container.

```
  ┌────────────────────────────────────────────────────────────────┐
  │  ┌──┐  LOL                                            ┌──────┐ │
  │  │ 🏋│                                                 │      │ │
  │  └──┘                                                 │  ▶   │ │
  │                                                       └──────┘ │
  │  ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄ │
  │                                                                │
  │  💡  Vorschlag                                          ✕      │
  │  Du hast die letzten 3 Sessions alle 10 Reps geschafft.        │
  │                                                                │
  │  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐   │
  │  │  MEHR GEWICHT   │ │   MEHR REPS     │ │    STABIL       │   │
  │  │                 │ │                 │ │                 │   │
  │  │   25 kg × 8     │ │   20 kg × 12    │ │   20 kg × 10    │   │
  │  │                 │ │                 │ │                 │   │
  │  │  +5 kg wie      │ │  letztes Mal    │ │  bleib wo du    │   │
  │  │  zuletzt        │ │  nur 10         │ │  bist           │   │
  │  └─────────────────┘ └─────────────────┘ └─────────────────┘   │
  │       ↑ tap                                                    │
  │       übernimmt Werte                                          │
  │       in Exercise &                                            │
  │       schließt Detail                                          │
  └────────────────────────────────────────────────────────────────┘
```

## STATE 5 — Nach Übernahme (zurück zu State 2 mit neuen Werten)

User hat "MEHR GEWICHT" getapt. `Exercise.weight = 25 kg, reps = 8`.
Card kollabiert zurück zur normalen Idle-Ansicht. metricRow zeigt neue Werte.

```
  ┌────────────────────────────────────────────────────────────────┐
  │  ┌──┐  LOL                                            ┌──────┐ │
  │  │ 🏋│                                                 │      │ │
  │  └──┘  Weight  │ Seat │ Progress                      │  ▶   │ │
  │        25 kg   │  +   │   📊  ⌄                       │      │ │
  │                                                       └──────┘ │
  └────────────────────────────────────────────────────────────────┘
```

## User Flow (State Machine)

```
      ┌───────────────────────────────────────┐
      │           STATE 1 / 2                 │
      │  Idle (collapsed)                     │
      │  - mit oder ohne Empfehlungs-Zeile    │
      └────────┬───────────────────┬──────────┘
               │                   │
       tap auf Card        tap auf 💡-Zeile
               │                   │
               ▼                   ▼
      ┌─────────────────┐ ┌────────────────────┐
      │   STATE 3       │ │    STATE 4         │
      │  Idle Expanded  │ │  Recommendation    │
      │  (Phasen-Tiles) │ │     Detail         │
      └────────┬────────┘ └─────┬────────┬─────┘
               │                │        │
        tap auf Card     tap auf Tile  tap ✕
               │                │        │
               ▼                ▼        │
        zurück zu          STATE 5 →    zurück zu
         STATE 1/2         (kurz)       STATE 1/2
                              │
                              ▼
                          STATE 1/2
                       (mit neuen Werten)
```

## Wichtige Design-Entscheidungen

**Wo der Trigger NICHT sitzt:**
- NICHT links neben dem Play-Button (konkurriert visuell)
- NICHT als Info-Icon (i) (wird laut NN/g ignoriert)
- NICHT in der metricRow neben Progress (zu wenig Platz)
- NICHT als TipKit-Tip (Apple sagt: TipKit nicht für recurring data)

**Wo der Trigger SITZT:**
- Eigene Zeile UNTER metricRow, ÜBER expandedContent
- Volle Card-Breite, klare Affordanz (Lightbulb + Chevron)
- Glass background mit white.opacity(~0.05) — ghost-style
- Play-Button bleibt unangetastet als primary CTA

**Anchor-Delta-Prinzip:**
- Nicht "+5 kg" allein, sondern immer mit Begründung dahinter
- "Because you…"-Sprache aus NN/g ML-UX research
- Bei null Konfidenz → Zeile gar nicht zeigen (lieber leer als falsch)

**One-Tap-Apply:**
- Tap auf Tile = sofort Werte übernehmen + Detail schließen
- Kein Bestätigungs-Dialog (würde Interaction-Cost erhöhen)
- Reversibel über Edit auf metricRow (existiert bereits)
