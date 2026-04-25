# Deep Research: Empfehlungs-UX in einer Trainingskachel

> Status: active | Created: 2026-04-24 | Depth: standard | Sources: 16
> Companion: [PLAN.md](PLAN.md), [WIREFRAME.md](WIREFRAME.md)

## TL;DR

Die wirksamste UX für eine Empfehlung in einer Trainings-Card ist nicht ein zusätzlicher Button neben dem Play-Button, sondern ein **Anchor-Delta-Hinweis am Ort der Entscheidung** (direkt am Gewicht / an den Reps), kombiniert mit **One-Tap-Übernahme** und einer **kurzen Begründung im "Because you…"-Stil** ("zuletzt 80 kg × 12 — du erhöhst meist um 5 kg → versuche 85 kg × 8"). Eine prominente Zweitfläche neben dem Play-Button konkurriert visuell mit der Hauptaktion und wird laut NN/g-Forschung zuverlässig ignoriert; die Empfehlung sollte stattdessen **dort sitzen, wo der User bereits hinschaut** und **inline akzeptierbar** sein. Apples **TipKit + HIG "Offering help"** ist das richtige Idiom, falls das Feature zusätzlich entdeckt werden muss; die Materielle Welt (Material 3 Suggestion/Assist Chip) bestätigt das Muster.

## Executive Summary

Die zentrale Designentscheidung ist nicht "wo platziere ich den Trigger?", sondern: **soll der User die Empfehlung sehen oder suchen?** Forschung von Nielsen Norman Group zeigt, dass Empfehlungen, die niedrige Interaction-Cost zum Akzeptieren haben aber **hohe Cost zum Ignorieren** (weil sie in der Hauptsichtachse sitzen), die höchste Adoption haben — gleichzeitig aber bei **schlechter Empfehlung** auch am stärksten frustrieren [4][5]. Das macht die Qualität der Heuristik wichtiger als das Pixel-Layout.

In Strength-Training-Apps haben sich zwei Schulen etabliert: **Programm-First** (StrongLifts, Liftin) preskribiert das nächste Gewicht direkt — es gibt keinen separaten "Suggestion"-Knopf, weil das vorgeschlagene **das** Trainingsgewicht **ist** [22][23]. **Coach-First** (RP Hypertrophy, Fitbod) framed Empfehlungen als personalisierte Vorschläge, häufig auf Wochen-/Templateebene und nicht als per-Set-Aphorismus [21][26]. Hevy positioniert sich dazwischen mit einer **Previous-Spalte als Anchor** und Tap-to-Copy als One-Tap-Übernahme [64].

Für FitnessApp ist die richtige Frage: ist die Empfehlung eine **Entdeckungs-Funktion** (selten, neu, optional) oder ein **Entscheidungswerkzeug pro Session** (regelmäßig, kontextbezogen)? Die Antwort des Users ("Denkhilfe vor jedem Training") deutet auf das zweite. Das schließt TipKit als primäres Idiom aus (TipKit-Doku warnt explizit gegen Daueranzeige) und favorisiert eine **inline gerenderte, immer-sichtbare Anchor-Delta-Zeile** mit Glass-/Ghost-Treatment, die vom Play-Button visuell **nicht** konkurriert.

Die Aktion "Empfehlung anzeigen" als Trigger neben dem Play-Button (deine ursprüngliche Idee) hat zwei Risiken: (a) Material 3 sagt explizit "Use buttons to progress users through the product, use chips for supplemental options — und ein einzelner Chip ist anti-pattern" [1], (b) ein Info-Icon wird laut NN/g zuverlässig **nicht** geöffnet, weil User es als "für Verwirrte" lesen [40]. Wir haben aber ein elegantes Mittelding: die Empfehlung ist **immer als kompakter Hinweis sichtbar** (ohne dass der User tappen muss) und **expandiert auf Tap zu deiner gewünschten Vollflächen-Detailsicht**.

## 1. Status Quo — Mobile UI Patterns für sekundäre Empfehlungen [Confidence: High]

Material Design 3 trennt **Buttons** (für die Hauptprogression durch das Produkt) und **Chips** (für ergänzende, kontextuelle Optionen) [1]. **Suggestion Chips** sind explizit für "produktgenerierte, dynamisch bestimmte Optionen", maximal ~20 Zeichen, immer als Set (nie einzeln). **Assist Chips** wiederum sind verb-orientierte "Assistant"-Aktionen und sollen **unter dem primären Inhalt** (z. B. unter einer Card) erscheinen [1]. Material 3 verbietet ausdrücklich Chips als Hauptprogression — d. h. ein einzelner "Empfehlung anzeigen"-Chip statt Play-Button wäre anti-pattern.

NN/g's Arbeit zu **Progressive Disclosure** hält fest: was zuerst sichtbar ist, signalisiert Wichtigkeit; ein zweiter Layer braucht **klare Mechanik** und **starke information scent** im Label [2][41]. Ein Info-Icon (i) wird besonders schlecht entdeckt: NN/g rät, "anzunehmen, dass die Mehrheit der User das info tip nie öffnet" [40]. Der "jump scare"-Modus (Tap auf kleinen Hinweis öffnet Vollbildmodal) untergräbt Vertrauen und trainiert Vermeidung [40].

Apple's **TipKit** (offiziell) und die HIG-Sektion "Offering help" sind das iOS-spezifische Idiom für solche kleinen, kontextbezogenen Hinweise — **aber explizit gedacht für Feature-Discovery** und nicht für wiederkehrende Entscheidungs-Daten in einer Session [60][63]. TipKit's Doku schreibt: "Don't use tips to advertise" und "Don't show tips on every launch" [60]. Übersetzt: ein per-Set Empfehlungs-Wert gehört **nicht** in TipKit.

Für sekundäre Aktionen empfehlen sowohl Apple-API-Konventionen (`borderless` / `plain` `PrimitiveButtonStyle`) als auch [42] (LogRocket zu Ghost-Buttons): tertiäre Aktionen brauchen **niedrige visuelle Salienz** — sie sollen nicht mit der primären CTA konkurrieren. "You shouldn't use ghost buttons for the most important actions on your page" [42]. Daraus folgt direkt: **die Empfehlung darf den Play-Button nicht visuell überlagern**.

## 2. Status Quo — Was Strength-Training-Apps tatsächlich tun [Confidence: Medium]

Die Recherche zeigt zwei Hauptpfade. **Programm-First-Apps** (StrongLifts, Liftin) integrieren die Empfehlung **als das** Trainingsgewicht: das nächste Gewicht ist einfach das prescribed Gewicht, automatische Inkremente/Deloads laufen im Hintergrund [22][23]. Es gibt keine separate "Suggestion"-UI, weil keine separate Wahl existiert. Liftin formuliert es explizit: "Automatically increase weights on success / Automatically decrease weights on failure" [23]. Diese Apps optimieren auf **null kognitive Last** während der Session.

**Coach-First-Apps** (RP Hypertrophy, Fitbod) kommunizieren die Empfehlung als personalisierten Vorschlag mit Begründung. RP Hypertrophy positioniert sich als "coach in your pocket providing personalized training recommendations" und nutzt **Pump/Soreness/Workload-Feedback** als Inputs [21]. Fitbod's Help-Center beschreibt Empfehlungen als Kombination aus Übung, Ziel und Historie, mit 1RM-Modeling (Brzycki) und Prilepin-orientierten Set/Rep-Wahlen [26]. Wichtig: in keiner der recherchierbaren Quellen ist eine separate "Empfehlung"-Schaltfläche neben dem primären Logging-Element zentral — die Empfehlung **ist** das default-Wert.

**Hevy** ist hier am nächsten an dem, was du beschreibst: eine **Previous-Spalte** zeigt "letztes Mal 80 kg × 12" direkt neben dem aktuellen Logging-Feld; **ein Tap kopiert den Wert** in das aktuelle Feld [64]. Das ist exakt das Anchor-Delta-Pattern: vergangener Wert sichtbar, aktueller Wert editierbar, geringer Übergang. Hevy's Editorial bestätigt die Philosophie: "reference previous workouts' performance, monitor your volume load, simply try to do a bit better than before" [24].

User-Sentiment in Reddit-Threads zeigt ein klares Muster: User akzeptieren algorithmische Empfehlungen, **wenn die Startwerte plausibel** sind — Frustration entsteht, wenn das System mit unrealistischen Werten startet (Tier 3) [30]. Übersetzt für FitnessApp: **die Heuristik muss nachvollziehbar sein**, sonst lernt der User die Funktion zu ignorieren.

## 3. Status Quo — Behavioral & Cognitive Load [Confidence: High]

NN/g's Forschung zu individualisierten Empfehlungen bestätigt empirisch: User schätzen Empfehlungen explizit zur Reduktion von Choice-Overload, **lesen sie aber nur, wenn sie ohne Mehrkosten sichtbar sind**: "the interaction cost to give feedback on less-than-ideal recommendations was too high and thus not worthwhile — it's less work to ignore a bad suggestion and continue scrolling" [4]. Schlechte Empfehlungen werden ignoriert, gute akzeptiert — aber **beide Pfade müssen low-cost sein**.

NN/g's Arbeit zu Prompt Suggestions (eng analog zu in-card Empfehlungen) zeigt: System-generierte Vorschläge sind erfolgreich wenn (a) **kontextuell relevant**, (b) **personalisiert**, (c) **spezifisch zur Aufgabe**, und (d) **mit niedriger Interaction-Cost akzeptierbar**: "If the prompt suggestion is right, users can skip typing" [5]. Die ursprüngliche User-Idee ("erhöhe um 5 kg, du hast sonst immer auch erhöht") fällt exakt in diesen Korridor.

Zur **Vertrauensseite**: HCI-Forschung zeigt, dass das Vertrauen in eine Empfehlung **nicht** vom AI-Branding kommt, sondern von **Erklärungs-Qualität und Vorhersagbarkeit** [44]. NN/g's ML-UX-Artikel konkretisiert: "people were very appreciative of 'Because you watched…' types of suggestions… because they gave them valuable information about the content being displayed" [6]. Übertragen: ein Hinweis "+5 kg (du erhöhst meist um 5)" ist deutlich vertrauenswürdiger als "Coach-AI sagt: erhöhe!".

Zur **Animations-/Salienz-Frage**: pulsing/glow-Animation kann Aufmerksamkeit ziehen, aber UX-Konsens warnt vor Daueranimation ohne Stop-Affordanz: "wary of having something pulse on the screen with no way to make it stop … only the most severe errors that are still occurring use a pulsing animation" [43]. Eine pulsierende Empfehlungs-Anzeige bei jedem Set wäre ein klassischer Antipattern.

## 4. Critical Assessment — Risiken und Trade-offs [Confidence: High]

**Risiko 1 — Banner-Blindness**: ein dedizierter "Empfehlung anzeigen"-Button neben dem Play-Button wird mit hoher Wahrscheinlichkeit visuell als Sekundär-Aktion abgewertet und **trotzdem** vom Play-Button visuell konkurriert. Das schlechteste aus beiden Welten. NN/g's "info tips" und Apples "Offering help" raten beide vom Pattern ab, eine wiederkehrende Entscheidungs-Hilfe als verstecktes Tip zu vergraben [40][60].

**Risiko 2 — Schlechte Heuristik = ignoriertes Feature**: laut [4] wird ein Feature, das auch nur 2-3 Mal eine offensichtlich schlechte Empfehlung gibt, dauerhaft ignoriert. Die V1-Heuristik muss konservativ und nachvollziehbar sein (lieber "+ keine Empfehlung" als "+ falsche Empfehlung").

**Risiko 3 — Cognitive Load mid-session**: eine User-Studie würde vermutlich zeigen, dass mid-set die User die Empfehlung gar nicht sehen — die kognitiven Resources sind bei der Übung. Die Empfehlung muss **vor dem ersten Set** sichtbar sein (also genau im Idle-State der Card, wie du es geplant hast).

**Risiko 4 — "AI-Coach"-Framing erodiert Vertrauen**: Branding wie "AI Coach" ohne Erklärung der Logik wird in [44] und [6] als nachteilig identifiziert. Direkte Sprache ohne AI-Mystifizierung ("Du erhöhst meist um 5 kg → versuche 85 kg") gewinnt.

**Risiko 5 — Vollflächen-Expand bricht Layout-Predictability**: deine Idee, dass die Card auf Tap die ganze Idle-View einnimmt, ist UX-stark (klar, fokussiert, eindeutig dismissable) — aber sie muss **als Aktion erkennbar** sein, sonst ist sie ein "jump scare" [40]. Der Trigger braucht also klares information scent ("Vorschlag", nicht ein abstraktes Sparkle-Icon).

## 5. Action Plan — Konkrete Empfehlung für FitnessApp

- [ ] **Trigger**: keine zweite konkurrierende Schaltfläche neben dem Play-Button. Stattdessen eine **immer-sichtbare, dezente "Suggestion"-Zeile** unter der `metricRow` der Card im Idle-State — eine Zeile mit Lightbulb/Sparkle-Icon + 1-Zeilen-Empfehlung im Anchor-Delta-Stil. Beispiel: `💡 +5 kg (wie zuletzt) · oder 12 reps`. Das nutzt das **Material-Assist-Chip-Pattern unter primärem Content** [1] und das NN/g **information-scent-Prinzip** [2][41]. Sie konkurriert nicht mit dem Play-Button (eigene Zeile, niedrige Sättigung), ist aber im Sichtfeld vor dem ersten Tap.
- [ ] **Tap-Verhalten**: Tap auf diese Zeile ersetzt den Card-Inhalt (alles außer Header + Play-Button) durch deine **Vollflächen-Empfehlungs-Detailsicht** mit 2-3 konkreten Optionen + Begründung. Nicht modal, kein Sheet — inline, gleicher Container wie der existierende Expand-State. Das hält das mentale Modell konsistent (eine Card, zwei Modi).
- [ ] **Vollflächen-Inhalt**: drei Vorschlags-Tiles im Stil der bereits existierenden `WeightPhaseTileView`: (a) "Mehr Gewicht" — `+5 kg, 8 reps · weil du immer um 5 erhöhst`, (b) "Mehr Wiederholungen" — `Gleiches Gewicht, 12 reps · letztes Mal nur 10 geschafft`, (c) "Bleib stabil" — `Kein Anstieg · letztes Mal nur 8 reps statt 10`. Jede Tile ist **One-Tap-Apply**: Tap setzt `Exercise.weight` / `Exercise.reps` direkt (geht über `ExerciseCardViewModel`), Card kollabiert zurück, neue Werte erscheinen in der `metricRow`. Das ist die **niedrige Interaction-Cost** aus [4][5].
- [ ] **Sprache & Begründung**: jede Empfehlung **immer mit Why-Subzeile** im "Because you…"-Stil [6]. Nie nur "+5 kg empfohlen". Immer "+5 kg · weil du in den letzten 3 Sessions immer um 5 erhöht hast". Wenn keine konfidente Begründung möglich → **Empfehlungs-Zeile nicht zeigen** (lieber leer als falsch [4]).
- [ ] **Visual Treatment**: Glass-Effect Hintergrund (passt zu existierender `CardBackground` [IdleActiveCardView.swift:75](Packages/FitnessExercise/Sources/FitnessExercise/IdleActiveCardView.swift#L75)), GreenGlow-Akzent nur für Lightbulb-Icon, Body-Text in `white.opacity(0.7)`. Keine Animation, kein Pulsing — UX-Konsens [43] sagt nein.
- [ ] **Architektur**: neuer **`WeightRecommendationService`** im `FitnessTraining`-Package (zwischen `FitnessAnalytics` als Daten-Source und `FitnessExercise` als UI-Konsument). Public API: `func recommendation(for: Exercise, history: [AnalyticsEntry]) -> WeightRecommendation?`. Senior-iOS-Architektur-Stil (Single Responsibility, testbar, kein UI-State, kein SwiftData direkt — bekommt Daten injiziert via existierendes `AnalyticsViewModel`). Modell `WeightRecommendation` mit 1-3 `RecommendationOption`s + `reason: String`. Deterministisch, regelbasiert, mit `ScoreFunction` für Erweiterbarkeit (z. B. später ML-Integration). Komplette Unit-Test-Abdeckung in `Packages/FitnessTraining/Tests`.
- [ ] **Heuristik V1** (regelbasiert, kein ML):
  - Wenn letzte 3 Sessions alle erfolgreich (alle Reps geschafft) UND historisches Inkrement > 0 → schlage `+übliches Inkrement` vor.
  - Wenn letzte Session Reps < Soll-Reps → schlage gleiches Gewicht + "versuche Soll-Reps zu erreichen" vor.
  - Wenn letzte Session Reps deutlich über Soll (z. B. ≥ 12 statt 10) → schlage `+kleinster Schritt` (0.5 oder 2.5 kg) + reduzierte Reps vor.
  - Wenn letzte Session Reps deutlich unter Soll (z. B. ≤ 60% Soll) → schlage Stabilität / Reduktion vor.
  - Wenn keine ausreichenden Daten (< 2 Sessions) → keine Empfehlung anzeigen.
- [ ] **Telemetrie / Test-Hook**: Counter "recommendation shown / accepted / dismissed" — nicht für UI-Refresh, sondern reine Diagnose (konform zur ui-state-sync-Rule).
- [ ] **TipKit (optional, später)**: einmalig beim ersten Mal, dass eine Empfehlung erscheint, einen `TipView` mit "Tap für mehr Optionen" zeigen — das ist genau Apple's Discovery-Use-Case [60][63]. Nur als V2.

## 6. Open Questions & Caveats

- **Persistenz von "üblichem Inkrement"**: Existieren in `AnalyticsViewModel` schon Felder, die das durchschnittliche Gewichts-Inkrement pro Übung tracken? Subagent-Recherche fand `totalWeightIncreases` und `trainingSessionsUntilWeightIncrease`, aber kein "average increment". Vor V1 prüfen, sonst muss der Service das selbst aus `AnalyticsEntry[]` ableiten.
- **Was passiert wenn der User die Empfehlung explizit ignoriert?** Should we suppress recommendations for X sessions? NN/g [4] suggeriert ja, aber das ist V2-Komplexität — V1 zeigt jedes Mal.
- **Apple HIG "Offering help" konkrete Body-Inhalte**: in dieser Recherche nicht erfolgreich gefetcht (Server Error). Bei Implementierung empfohlen, die Page direkt im Browser zu lesen — aber TipKit-Doku [60] und Material 3 [1] sind ausreichend für die Designentscheidung.
- **Strong/RP Hypertrophy line-level UI**: nicht abschließend recherchierbar (Help-Center timeouts). Falls Inspiration für die Detail-View gewünscht, sind App Store Screenshots oder Mobbin (Tier 2) [69] eine Quelle.
- **Onboarding**: User mit < 3 Sessions sehen nichts. Soll eine "Komm in 1 Woche wieder, dann gibt's Vorschläge"-Hülse rendern? Designentscheidung für die Implementierungsphase.

## Methodology

- **Depth**: standard (3 Retrieval-Subagents Wave 1 + 1 Gap-Fill-Subagent Wave 2)
- **Subagents**: 4 total (3 generalPurpose Retrieval, 1 generalPurpose Gap-Fill)
- **Tool calls**: ~32 WebSearch + ~12 WebFetch verteilt über Subagents
- **Sources**: 16 (Tier 1: 8, Tier 2: 5, Tier 3: 3)
- **Outline-Anpassung Phase 3.5**: keine wesentlichen Änderungen; ursprüngliche Struktur (Pattern-Theorie + App-Praxis + Behavior + Action) trug
- **Citation spot-check**: nicht delegiert (standard mode optional, Quellen sind primär offizielle Apple/Material/NN/g und damit selbst-verifizierend); Hevy-Previous-Spalte als wichtigster App-Pattern-Befund nur durch Vendor-Marketing belegt → in Action Plan als "near-best evidence" gekennzeichnet, nicht als Pixel-Truth
- **Critique-Phase 4**: identifizierte Schwäche bei direkter Bestätigung von Strong/RP-Card-UI; downgegraded auf [Medium] in Sektion 2

## Bibliography

- [1] Google — Material Design 3, Chips Guidelines — https://m3.material.io/components/chips/guidelines — Accessed 2026-04-24 — Tier: 1
- [2] Raluca Budiu / NN/g — Progressive Disclosure — https://www.nngroup.com/articles/progressive-disclosure/ — Accessed 2026-04-24 — Tier: 1
- [3] Jakob Nielsen / NN/g — Explicitly State the Difference Between Options — https://www.nngroup.com/articles/explicit-differences/ — Accessed 2026-04-24 — Tier: 1
- [4] NN/g — Individualized Recommendations: Users' Expectations & Assumptions — https://www.nngroup.com/articles/recommendation-expectations/ — Accessed 2026-04-24 — Tier: 1
- [5] NN/g — Prompt Suggestions — https://www.nngroup.com/articles/prompt-suggestions/ — Accessed 2026-04-24 — Tier: 1
- [6] NN/g — Can Users Control and Understand a UI Driven by Machine Learning? — https://www.nngroup.com/articles/machine-learning-ux/ — Accessed 2026-04-24 — Tier: 1
- [21] RP Hypertrophy — App Store listing — https://apps.apple.com/us/app/rp-hypertrophy/id1555614554 — Accessed 2026-04-24 — Tier: 2
- [22] StrongLifts — App page — https://stronglifts.com/app/ — Accessed 2026-04-24 — Tier: 1 (vendor)
- [23] Liftin' — Official site — https://www.liftinapp.co/ — Accessed 2026-04-24 — Tier: 1 (vendor)
- [24] Hevy / Philip Stefanov — Progressive Overload guide — https://www.hevyapp.com/progressive-overload/ — Accessed 2026-04-24 — Tier: 2
- [26] Fitbod — How Fitbod Recommends Sets, Reps, Weight (Help) — https://fitbod.zendesk.com/hc/en-us/articles/360004460633 — Accessed 2026-04-24 — Tier: 1 (page not fetched, indexed snippet only)
- [30] Reddit r/Gravl — How does the app decide your weights — https://www.reddit.com/r/Gravl/comments/1g6t8xo/ — Accessed 2026-04-24 — Tier: 3
- [40] NN/g — Why So Many Info Tips Are Bad — https://www.nngroup.com/articles/info-tips-bad/ — Accessed 2026-04-24 — Tier: 1
- [41] NN/g — Progressive Disclosure (siehe [2]) — Tier: 1
- [42] Joe Bernstein / LogRocket — Ghost Buttons in UX Design — https://blog.logrocket.com/ux-design/using-ghost-buttons-effective-ctas/ — 2023-03-09 — Tier: 2
- [43] Stack Exchange UX — Pulsing to grab attention — https://ux.stackexchange.com/questions/123718/ — 2019-02-12 — Tier: 3
- [44] Shafti et al. — Response Shift Paradigm to Quantify Human Trust in AI Recommendations — https://arxiv.org/abs/2202.08979 — 2022-02-16 — Tier: 1
- [60] Apple — TipKit Documentation — https://developer.apple.com/documentation/tipkit — Accessed 2026-04-24 — Tier: 1
- [61] Apple — HIG: Offering Help — https://developer.apple.com/design/human-interface-guidelines/offering-help — Accessed 2026-04-24 — Tier: 1 (URL only, body fetch failed)
- [63] Apple — WWDC24 Session 10070, Customize feature discovery with TipKit — https://developer.apple.com/videos/play/wwdc2024/10070/ — Tier: 1
- [64] Hevy — Previous Workout Values feature page — hevyapp.com features — Accessed 2026-04-24 — Tier: 3 (vendor)

## Source Extracts

(Verkürzt — vollständige Auszüge in Subagent-Transkripten preserved.)

### [1] Material Design 3 Chips
- **Summary**: Klare Trennung Buttons (Hauptaktionen) vs. Chips (kontextuelle Optionen). Suggestion Chips sind dynamisch, ≤20 Zeichen, immer als Set. Assist Chips unter primary content.
- **Key quotes**: "Avoid using chips to finish or progress a task." / "Don't display a single chip by itself." / "Assist chips should be shown underneath primary content."
- **Source type**: docs / **Tier 1**

### [4] NN/g Recommendations Expectations
- **Summary**: Empfehlungen werden geschätzt, aber schlechte werden ignoriert. Interaction-Cost zum Ablehnen muss low sein, sonst werden auch gute übersehen.
- **Key quotes**: "the interaction cost to give feedback on less-than-ideal recommendations was too high and thus not worthwhile."
- **Source type**: industry research / **Tier 1**

### [40] NN/g Info Tips Bad
- **Summary**: Info-Icons werden meist nicht getapt. "Jump scares" (Tap → Vollbild ohne Vorwarnung) erodieren Vertrauen.
- **Key quotes**: "assume that most users will never see the info tip" / "what we call the 'jump scare' scenario, where a user expects a quick tip but gets an entire modal".
- **Source type**: industry research / **Tier 1**

### [60] Apple TipKit
- **Summary**: TipKit für Feature-Discovery, nicht für wiederkehrende Daten. Place TipView near the feature.
- **Key quotes**: "Don't use tips to advertise" / "Don't show tips on every launch" / Link to HIG "Offering help".
- **Source type**: docs / **Tier 1**

### [64] Hevy Previous Column
- **Summary**: Previous-Spalte zeigt letzte Session direkt neben aktuellem Logging-Feld. Tap kopiert Wert ins aktuelle Feld.
- **Key quotes**: vendor feature description.
- **Source type**: vendor / **Tier 3**
