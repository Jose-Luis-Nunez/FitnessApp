# Deep Research: Cursor Skills für XCUITest UI-Test-Automatisierung

> Generated 2026-04-07 | Depth: deep | Sources: 27

## TL;DR

Die FitnessApp UI-Test-Skills sind architektonisch solide und liegen **vor** dem, was die Community öffentlich zeigt — die meisten Teams nutzen nur Cursor Rules, keine Skills für Tests. Die Hauptverbesserungspotenziale liegen in der **Selector-Schicht** (Enum-Patterns mit computed properties statt reiner String-Konstanten), der **DSL-Benennung** (Robot Pattern statt generischer Hilfsfunktionen), und einer klareren **Identifier-Strategie** mit hierarchischen, dot-separierten IDs.

## Executive Summary

Diese Analyse untersucht, wie Cursor Skills und Agents für XCUITest-Automatisierung strukturiert werden sollten — aus der Cursor-Plattform-Perspektive und aus der XCUITest-Community. Die Recherche deckt 7 Key Areas ab: Cursor Skill Architecture, Agent Orchestration, XCUITest DSL Design (Page Object / Robot Pattern), Accessibility Identifier Strategien, Selector Management, Test Architecture Patterns und AI-gestützte Test-Generierung.

**Kernerkenntnisse:** Cursors Skill-System ist für genau diese Art von workflow-orientierter Automatisierung gebaut — progressive disclosure, dynamisches Laden, Subagent-Delegation [2]. Die XCUITest-Community hat zwei dominante Patterns etabliert: das **Page Object Model** (REI, Applitools) [21][43] und das **Robot Pattern** (Jake Wharton / Jean Handguy) [24], die beide auf Identifier-basierte Selectors in Enum-Form setzen [41][42]. Kritisch ist die Erkenntnis, dass AI-generierte Tests systematisch dazu neigen, eigene Annahmen statt echtes Nutzerverhalten zu testen [60], was human-in-the-loop Workflows wie den der FitnessApp-Skills (Prep → Write → Review) validiert. Die FitnessApp-Architektur mit getrennten Skills, shared Reference und zwei spezialisierten Agents ist ein Pattern, das es öffentlich kaum gibt — die meisten Cursor-Test-Setups beschränken sich auf Rules [71][72][75].

## 1. Cursor Skill Architecture [Confidence: High]

Cursors offizielles Skill-System und die Agent Skills Spezifikation [1] definieren eine klare Hierarchie: `SKILL.md` als Einstiegspunkt mit YAML-Frontmatter (`name` + `description`), unterstützt durch optionale `reference.md`, `examples.md` und `scripts/` [1]. **Progressive Disclosure** ist ein Kernprinzip: nur die Metadaten (Name, Description) werden beim Start geladen, der SKILL.md-Body erst bei Aktivierung, und referenzierte Dateien on-demand [1][2].

Die offizielle Empfehlung ist, SKILL.md unter **500 Zeilen** zu halten und längere Inhalte in separate Dateien auszulagern [1]. Die Description ist der kritischste Teil — sie entscheidet, ob der Agent den Skill überhaupt aktiviert. Best Practice: beschreibe sowohl **was** der Skill tut als auch **wann** er verwendet werden soll, mit konkreten Trigger-Keywords [1][2].

Ein fundamentaler Unterschied zu Rules: **"Unlike Rules which are always included, Skills are loaded dynamically when the agent decides they're relevant"** [2]. Das bedeutet: Rules für immer-gültige Constraints (Style-Guide, Architektur), Skills für situative Workflows (Test schreiben, Test updaten). Dieser Split ist in der FitnessApp korrekt umgesetzt.

**Shared Reference Files** zwischen Skills sind im Spec nicht explizit vorgesehen — das Standard-Pattern ist `reference.md` innerhalb eines Skill-Ordners [1]. Die FitnessApp-Lösung (eigenständiger `ui-test-conventions/`-Ordner) ist eine pragmatische Abweichung, die Duplikation vermeidet. Die Alternative wäre, die Conventions als **Rule** (always-on) statt als shared Reference zu implementieren — das würde garantieren, dass sie immer im Kontext sind, unabhängig davon welcher Skill geladen wird.

## 2. Agent Orchestration [Confidence: High]

Cursor positioniert den Agent-Harness als drei Hebel: **Instructions** (Rules + Skills), **Tools** und **Model** [2]. Subagents operieren in **isoliertem Kontext**, was verhindert, dass Explore- oder Shell-Arbeit den Hauptagenten überschwemmt [4]. Seit Cursor 2.5 gibt es **async/background Subagents** und Sandbox-Kontrollen [5].

Für **Parallelisierung** empfiehlt Cursor **git worktrees**, damit Agents sich nicht gegenseitig blockieren, und **multi-model runs** für Vergleiche [2]. Cloud/Background-Agents können Tests generieren, während der Entwickler lokal arbeitet [2].

Die FitnessApp-Architektur mit zwei **readonly, foreground** Agents (Prep + Reviewer) ist konservativ aber korrekt. Die Agents verändern nichts, sie berichten — der Hauptagent entscheidet. Das passt zum Cursor-Modell, wo Subagents spezialisierte, isolierte Aufgaben übernehmen. Die parallele Ausführung von Prep + Reviewer im Update-Workflow nutzt die Plattform-Fähigkeit effizient.

**Model-Wahl:** `fast` für beide Agents ist richtig — sie scannen und matchen Patterns, brauchen kein Deep Reasoning [2]. Das spart Kosten und Latenz.

## 3. XCUITest DSL Design [Confidence: High]

Die XCUITest-Community hat zwei dominante Patterns für Test-Abstraktion:

### Page Object Model (POM)

REI Engineering [21] beschreibt POM als strukturierte Interfaces, bei denen jede Screen-Klasse Navigations-Methoden anbietet, die den nächsten Screen-Typ zurückgeben. Zentral ist **Synchronisation**: `waitForView()` / `checkViewCriteria()` vor und nach jeder Interaktion. REI erweitert das Pattern um **Page Components** (wiederverwendbare UI-Chunks) und **Collections** (Listen von gleichartigen Elementen) [21].

### Robot Pattern

Das Robot Pattern, ursprünglich von Jake Wharton für Android vorgestellt und von Jean Handguy für iOS adaptiert [24], trennt **Was** (Test) von **Wie** (Robot). Tests lesen sich als Intent-Beschreibungen, Robots kapseln die Interaktionslogik. Robots nutzen `@discardableResult`-Chains für fluente APIs und halten `XCUIElement`-Queries als lazy Properties [24].

**Vergleich mit FitnessApp:** Die aktuelle DSL der FitnessApp (freie Funktionen wie `tapOn`, `verifyExists`) ist ein **flacher Ansatz** — weder POM noch Robot. Das funktioniert bei wenigen Tests, aber skaliert schlechter, weil:
- Es gibt keine Screen-Zuordnung (welcher `tapOn` gehört zu welchem Screen?)
- Keine fluente API (kein Chaining, kein typisierter Rückgabewert)
- Keine Synchronisations-Garantie auf Screen-Ebene

Für die aktuelle Größe (1 Testklasse) ist das akzeptabel. Bei Wachstum wäre der Robot Pattern der natürlichere nächste Schritt — er ist weniger aufwändig als POM und behält die Lesbarkeit.

## 4. Accessibility Identifiers [Confidence: High]

Apple definiert `accessibilityIdentifier` als String, der **ein Element für UI Automation Scripts eindeutig identifiziert** und verhindert, dass das `accessibilityLabel` (für VoiceOver) zweckentfremdet wird [20]. Paul Hudson bestätigt: **"The accessibility identifier is designed for internal use only, unlike the other two accessibility text fields that are read to the user when Voiceover is activated"** [22].

Kamil Wyszomierski [23] schlägt für SwiftUI-Projekte **hierarchische, dot-separierte Identifiers** vor (z.B. `health.summary.heartRate.value`), die über SwiftUI `EnvironmentKey` + Branch/Leaf-Modifier zusammengesetzt werden — ähnlich wie Layout-Modifier, ohne View-Initializer zu verschmutzen.

**Vergleich mit FitnessApp:** Die aktuelle Naming-Convention `id_<context>_<element>` (z.B. `id_button_start`) ist funktional, aber flacher als der Community-Konsens. Hierarchische IDs (`training.sets.doneButton`) würden bei wachsender App-Komplexität besser skalieren. Eine wichtige Warnung aus [64]: Test-Only Accessibility Values können in VoiceOver leaken — bei Identifier ist das weniger kritisch als bei Values, aber Disziplin bleibt nötig.

## 5. Selector Management [Confidence: Medium]

Der Community-Konsens ist klar: **Selectors gehören in Enums** [41][42][43]. REI geht am weitesten mit `enum Element` + `func locator(_ context: XCUIElement) -> XCUIElement` + nested `enum Constants: String` [41] — das kapselt nicht nur den String, sondern auch die Query-Logik.

Applitools TAU empfiehlt, Elemente, Steps und Tests physisch in separate Dateien zu trennen [43]. DZone/Bitbar bestätigt das Base-Class-Pattern für gemeinsamen Setup [44].

**Vergleich mit FitnessApp:** Die Selector-Enums (`HomeSelectors`, `TrainingSelectors`) als reine `static let`-String-Konstanten sind der einfachste Ansatz. REIs Pattern mit computed `element`-Properties wäre der nächste Schritt:

```swift
enum TrainingSelectors: String {
    case startButton = "id_button_start"
    case doneButton = "id_button_done"

    var element: XCUIElement {
        XCUIApplication().descendants(matching: .any)
            .matching(identifier: rawValue).firstMatch
    }
}
```

Das würde die DSL-Funktionen (`tapOn`) vereinfachen, weil der Selector direkt ein Element liefert statt nur einen String.

## 6. Test Architecture [Confidence: Medium]

Die Praxis-Quellen konvergieren auf eine **Drei-Schichten-Architektur** [43][44]:

1. **Base** — `XCTestCase`-Subklasse mit shared `app`, setup/teardown, Launch-Argumente
2. **Locators / Selectors** — Enums oder Page Objects mit Element-Definitionen
3. **Tests** — Test-Klassen, die nur Base + Locators konsumieren

Die FitnessApp-Struktur (`Base/`, `DSL/`, `Selectors/`, `*Tests.swift`) bildet das ab, mit `DSL/` als zusätzlicher Schicht für freie Interaktions-Funktionen. Das ist eine valide Vierer-Schichtung.

## 7. AI-gestützte UI-Test-Generierung [Confidence: Medium]

Die Gap-Fill-Recherche [70]–[82] zeigt: **Cursor Skills für UI-Tests sind Pionierarbeit**. Die überwiegende Mehrheit der Community nutzt **Cursor Rules** (`.cursor/rules/*.mdc` mit `globs` für Test-Ordner) statt Skills [71][72][75]. Konkrete Skill-Beispiele für XCUITest existieren öffentlich kaum — das every.tv-Blog [6][73] ist das einzige substanzielle Beispiel, und es nutzt Rules statt Skills.

Kritisch ist die Erkenntnis von BetterQA [60]: **"The AI had tested its own assumptions about how the application should behave. It never tested how a real person would actually use it."** Applitools ergänzt [61]: generative AI ist probabilistisch und kann keine deterministischen Ausführungsgarantien geben — **"When failures aren't repeatable, teams stop trusting their tests."**

Die FitnessApp-Architektur adressiert das durch den **human-in-the-loop** Ansatz: AI generiert/reviewed (Prep + Reviewer Agents), aber der Mensch entscheidet und fixt. Das ist genau das von der Community empfohlene Pattern [60][61].

## 8. Critical Assessment [Confidence: High]

### Over-Engineering Risiko

Niraj Subedi [62] warnt: **"You spend more time managing the framework than testing the app."** Für die FitnessApp mit aktuell 1 Testklasse und ~20 Zeilen Test-Code sind 5 Cursor-Dateien (2 Skills, 1 Reference, 2 Agents) eine hohe Ratio. Das Investment zahlt sich erst aus, wenn die Test-Suite wächst.

### Accessibility-Identifier-Kopplung

Test-Only Identifier koppeln Tests an Implementation Details [64]. Jede Refaktorierung, die Identifier ändert, bricht Tests. Die Mitigation (Identifier als Konstanten in Selector-Enums) verschiebt das Problem, löst es aber nicht.

### AI-Test-Qualität

Fazm [63] berichtet, dass der Wechsel zu **post-action accessibility tree traversal** die Erfolgsrate von 37% auf 85% hob — nicht bessere Locators, sondern bessere Verification nach jeder Aktion war der Schlüssel. Die FitnessApp-DSL hat das teilweise durch `retryAction` und `waitForExistence` in `findElement`, aber nicht als explizites Post-Action-Pattern.

## Action Plan

- [ ] **Selector-Enums mit computed properties erweitern** — `rawValue`-basierte Enums statt `static let`, die direkt `XCUIElement` liefern können [41][42]
- [ ] **Hierarchische Identifier-Convention evaluieren** — `screen.group.element` statt `id_context_element` für bessere Skalierbarkeit [23]
- [ ] **Robot Pattern als optionalen Evolutionspfad dokumentieren** — in `reference.md` als "Next Step" Sektion, nicht als sofortige Anforderung [24]
- [ ] **UI-Test-Conventions als Rule statt shared Reference erwägen** — eine `.cursor/rules/ui-test-conventions.mdc` mit `globs: ["FitnessAppUITests/**"]` wäre always-on und braucht keine Cross-Skill-Referenz [2][75]
- [ ] **Post-Action Verification Pattern in DSL ergänzen** — nach jeder Interaktion den erwarteten Zustand verifizieren, nicht nur Retry bei Nicht-Existenz [63]

## Open Questions & Caveats

1. **Skalierungs-Schwelle:** Ab wie vielen Tests lohnt sich der Wechsel von flachen DSL-Funktionen zu Robot/POM? Die Quellen nennen keine konkrete Zahl — die Entscheidung ist projektspezifisch.

2. **Protocol-based Selectors:** Kein Material gefunden, das Protocols als Selector-Pattern empfiehlt. Enum-Patterns dominieren klar.

3. **Cursor Skills vs. Rules für Tests:** Die Community nutzt fast ausschließlich Rules. Skills sind mächtiger (progressive disclosure, dynamisches Laden), aber ob der Mehraufwand sich für Test-Workflows lohnt, ist eine offene Frage. Die FitnessApp ist hier ein Early Adopter.

4. **Source #5 (Applitools TAU)**: Die genaue Dreiteilung "Elements / Steps / Tests" wird von TAU nicht wörtlich so empfohlen — TAU spricht von separaten Projekten und Page Objects. Das Drei-Dateien-Pattern stammt eher aus der konsolidierten Community-Praxis. [Confidence für diese spezifische Claim: Low]

## Methodology

- **Depth:** Deep (4 Retrieval + 1 Gap-Fill + 1 Verification Subagent)
- **Waves:** 2 (initial retrieval + gap-fill for Cursor-specific test patterns)
- **Sources collected:** 27 unique (after deduplication)
- **Citation verification:** 7 claims spot-checked — 6 SUPPORTED, 1 PARTIAL (reformulated)
- **Outline changes:** Added Section 8 (Critical Assessment) based on strong evidence from opposing-views retrieval
- **Known limitation:** XCUITest + Cursor Skills is a niche topic with very few public examples; confidence for Area 7 is based more on adjacent evidence (Playwright/Cypress + Cursor) than direct XCUITest community patterns

## Bibliography

[1] Agent Skills Specification — agentskills.io — Accessed 2026-04-07 — Tier: 1
[2] Cursor — "Best practices for coding with agents" — cursor.com/blog — Accessed 2026-04-07 — Tier: 1
[3] Cursor — Agent Skills documentation — cursor.com/docs/context/skills — Accessed 2026-04-07 — Tier: 1
[4] Cursor — Subagents documentation — cursor.com/docs/context/subagents — Accessed 2026-04-07 — Tier: 1
[5] Cursor — Changelog 2.5 (Async Subagents) — cursor.com — Accessed 2026-04-07 — Tier: 1
[6] Narita / every.tv — "CursorでXCUITestの仕組みを使ったワークフロー" — tech.every.tv — 2026-01-26 — Tier: 2
[7] Various — iBuildWith.ai, ADevGuide, Cursor forum threads — Tier: 3
[8] AgentPatterns.ai — Progressive disclosure for agents — Tier: 3
[20] Apple Inc. — accessibilityIdentifier (UIAccessibilityIdentification) — developer.apple.com — Tier: 1
[21] REI Co-op Engineering — "XCUITest Automation: Page Object Models" — engineering.rei.com — Tier: 2
[22] Paul Hudson — "Xcode UI Testing Cheat Sheet" — hackingwithswift.com — 2019-10-14 — Tier: 2 [foundational]
[23] Kamil Wyszomierski — "Composing Accessibility Identifiers for SwiftUI" — Better Programming — 2023-07-14 — Tier: 2
[24] Jean Handguy — "UI Testing in iOS - Robot Pattern" — jhandguy.github.io — Tier: 3
[41] REI Co-op Engineering — "XCUITest: Encapsulating Element Locators in Swift Enumerations" — engineering.rei.com — Tier: 2
[42] XCTEQ — "Organising XCUIElements with Swift Enumerations" — xcteq.co.uk — Tier: 3
[43] Applitools TAU — "Introduction to iOS Test Automation with XCUITest – Chapter 5" — testautomationu.applitools.com — Tier: 2
[44] Shashikant Jagtap / DZone — "Writing DRY XCUITest Tests With Base Classes" — dzone.com — 2018-10-16 — Tier: 2 [foundational]
[60] Tudor B. / BetterQA — "We automated with AI - every test passed, nothing worked" — betterqa.co — 2026-02-05 — Tier: 2
[61] Applitools — "What Test Execution Demands That Generative AI Can't Guarantee" — applitools.com — Tier: 2
[62] Niraj Subedi — "Why I Don't Use POM in Small Mobile Automation Projects" — Medium — 2025-05-21 — Tier: 3
[63] Fazm — "From 37% to 85% UI Automation Success Rate" — fazm.dev — Tier: 2
[64] Testableapple — "Test-only accessibility values on iOS" — testableapple.com — Tier: 3
[71] Darpan Shah — "Cypress + Cursor: Smarter Code Suggestions with Rules" — darpanshah.dev — Tier: 3
[72] Herneysan — "AI-Powered Test Automation: Cypress + Cursor" — Medium — Tier: 3
[75] Cursor — Rules documentation — docs.cursor.com/context/rules — Tier: 1
[73] Narita / every.tv (same as [6]) — Tier: 2

## Source Extracts

### [1] Agent Skills Specification
- **Summary:** Defines skill directory layout (SKILL.md, references/, scripts/, assets/), frontmatter rules (name, description), progressive disclosure, and recommends <500 lines for SKILL.md.
- **Key quotes:** "Keep your main SKILL.md under 500 lines." / "The name and description fields are loaded at startup for all skills."
- **Source type:** Specification
- **Credibility tier:** 1

### [2] Cursor — Agent Best Practices
- **Summary:** Positions Rules as always-on vs Skills as dynamically loaded. Describes agent harness, parallel agents via worktrees, TDD loops, hooks for iterate-until-pass.
- **Key quotes:** "Unlike Rules which are always included, Skills are loaded dynamically when the agent decides they're relevant."
- **Source type:** Official blog
- **Credibility tier:** 1

### [20] Apple — accessibilityIdentifier
- **Summary:** Identifier uniquely identifies element for UI Automation, avoids misusing accessibility label.
- **Key quotes:** "Using an identifier allows you to avoid inappropriately setting or accessing an element's accessibility label."
- **Source type:** Official documentation
- **Credibility tier:** 1

### [21] REI — Page Object Models
- **Summary:** POM with synchronization foundation, typed navigation returns, page components, collections, enum locators.
- **Key quotes:** "In user interface automation, everything begins and ends with definite synchronization."
- **Source type:** Engineering blog
- **Credibility tier:** 2

### [23] Wyszomierski — Composing Accessibility Identifiers
- **Summary:** Hierarchical dot-separated IDs via SwiftUI EnvironmentKey + branch/leaf modifiers.
- **Key quotes:** "Accessibility identifiers can be used to reliably distinguish an element in UI automated tests. The alternatives either have low performance or require specific selectors that may randomly fail."
- **Source type:** Engineering blog
- **Credibility tier:** 2

### [24] Handguy — Robot Pattern iOS
- **Summary:** Robot separates What (test) from How (robot), fluent API with @discardableResult chaining.
- **Key quotes:** "Common UI Tests are mixing the What and the How altogether, in one place."
- **Source type:** Personal blog
- **Credibility tier:** 3

### [41] REI — Enum Locators
- **Summary:** Comprehensive enums with locator(context:), rawValue, nested Constants for element queries.
- **Key quotes:** "By defining all aspects of each target element in a single place, the task of debugging and maintaining element locators is greatly simplified."
- **Source type:** Engineering blog
- **Credibility tier:** 2

### [60] BetterQA — AI Testing Failure
- **Summary:** AI tested its own assumptions, not real user behavior. All tests passed but the app was broken.
- **Key quotes:** "The AI had tested its own assumptions about how the application should behave. It never tested how a real person would actually use it."
- **Source type:** Engineering blog
- **Credibility tier:** 2

### [61] Applitools — Generative AI Limitations
- **Summary:** LLMs are probabilistic, test execution needs determinism. Non-repeatable failures erode trust.
- **Key quotes:** "When failures aren't repeatable, teams stop trusting their tests—and that's when automation becomes a bottleneck instead of a benefit."
- **Source type:** Engineering blog
- **Credibility tier:** 2

### [63] Fazm — 37% to 85% Success Rate
- **Summary:** Post-action accessibility tree traversal was the biggest reliability improvement.
- **Key quotes:** "The single most impactful change was adding post-action accessibility tree traversal." / "'In the tree' does not mean 'interactive.'"
- **Source type:** Engineering blog
- **Credibility tier:** 2
