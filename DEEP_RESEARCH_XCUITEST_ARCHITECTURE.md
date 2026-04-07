# Deep Research: Moderne, schnelle & wartbare XCUITests

> Generated 2026-04-07 | Depth: standard | Sources: 18

## TL;DR

Wartbare XCUITests basieren auf drei Säulen: **Screen-Abstractions** (Page Object oder Robot Pattern) trennen Test-Logik von UI-Queries, **strikte Synchronisation** (`waitForExistence`, Predicates, Xcode-16-APIs) ersetzt jedes `sleep()`, und **Test-Isolation** via `launchArguments`/`launchEnvironment` plus optionale Tunnel-Libraries (SBTUITestTunnel) ermöglicht deterministische Zustände. Lange Flows werden in **komposierbare Segmente** zerlegt, die einzeln und als Ende-zu-Ende-Kette laufen können. Für die FitnessApp bedeutet das: Screen Objects pro Feature-Modul (Training, Schedule, Picker), ein app-seitiger Reset-Mechanismus über Launch-Flags, und eine Handvoll kritischer E2E-Tests für den Workout-Flow, ergänzt durch fokussierte Tests pro Screen.

## Executive Summary

XCUITest bleibt Apples einziges offizielles Framework für Black-Box-UI-Tests auf iOS. Es läuft out-of-process — der Testrunner steuert die App über die Accessibility-Hierarchie, ohne direkten Zugriff auf Models oder Services [1][2]. Das macht Tests realistisch, aber auch langsamer und schwerer zu isolieren als Unit-Tests.

Die Community hat sich auf zwei dominante Architektur-Patterns eingependelt: **Page Object Model (POM)** und **Robot Pattern**. Beide trennen das *Was* (Testintention) vom *Wie* (Element-Queries und Gesten) und liefern navigierbare Rückgabetypen für Screen-Übergänge [3][4]. Für lange Flows — wie einen kompletten Workout-Durchlauf mit Übungsauswahl, Active Sets, Timer und Abschluss — ist diese Trennung essentiell, weil Änderungen an einem Screen nur dessen Screen Object betreffen.

Synchronisation ist der häufigste Grund für flaky Tests. Apple hat in Xcode 16 zwei lang ersehnte APIs nachgeliefert: `waitForNonExistence(withTimeout:)` und `wait(for:toEqual:timeout:)` [6][7]. Zusammen mit der bewährten `waitForExistence(timeout:)` decken sie die meisten Wartebedürfnisse ab, ohne auf `sleep()` oder die langsame `XCTNSPredicateExpectation` (Mindest-Timeout ~1.1s durch Polling) zurückgreifen zu müssen [8][9].

Für Netzwerk-Isolation im out-of-process-Modell gibt es zwei Wege: **App-seitige Feature-Flags** (einfach, keine Abhängigkeit) oder **Tunnel-Libraries** wie SBTUITestTunnel (mächtiger, aber Integrationsaufwand) [5][14]. Ergänzende Tools wie swift-snapshot-testing [15] und ViewInspector [16] können UI-Regressionstests *unterhalb* der XCUITest-Ebene abfangen und so den teuren E2E-Anteil reduzieren.

---

## 1. Status Quo: Etablierte Patterns [Confidence: High]

### 1.1 Page Object Model & Robot Pattern

Die zwei vorherrschenden Architektur-Ansätze für XCUITest-Code sind das **Page Object Model (POM)** und das **Robot Pattern**. Beide verfolgen dasselbe Ziel — die Trennung von Test-Logik und UI-Interaktion — unterscheiden sich aber in ihrer API-Oberfläche.

Beim **POM** repräsentiert eine Swift-Klasse oder Struct einen Screen der App. Jedes Page Object kapselt die `XCUIElement`-Queries für diesen Screen und bietet Methoden, die User-Aktionen abbilden. Navigation-Methoden geben dabei den *nächsten* Screen-Typ zurück, sodass der Compiler ungültige Transitionen erkennt [3]. REI Engineering empfiehlt zusätzlich ein `SynchronizedView`-Protocol mit `waitForView()` und `checkViewCriteria()`, damit jede Navigation erst nach erfolgreichem Screen-Load fortfährt — nach dem Prinzip „Fail Fast with Detailed Diagnostics" [3].

```swift
// Page Object mit typisierter Navigation
protocol Screen {
    var app: XCUIApplication { get }
    func waitForScreen() -> Self
}

struct TrainingScreen: Screen {
    let app: XCUIApplication

    @discardableResult
    func waitForScreen() -> Self {
        let title = app.staticTexts["Training"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        return self
    }

    func tapExercise(_ name: String) -> ActiveSetScreen {
        app.buttons[name].tap()
        return ActiveSetScreen(app: app).waitForScreen()
    }
}
```

Das **Robot Pattern** (populär durch Jake Wharton, adaptiert für iOS u.a. von Capital One und Jean Varloot [4]) verwendet stattdessen fluente `@discardableResult`-Chains. Tests lesen sich wie Szenarien in natürlicher Sprache, während Robots die technischen Details kapseln [4]:

```swift
func testWorkoutCompletion() {
    TrainingRobot(app: app)
        .verifyScreenLoaded()
        .tapExercise("Bench Press")
        .enterWeight(80)
        .confirmSet()
        .verifySetCompleted()
}
```

Beide Patterns sind in der Praxis bewährt. Die Wahl hängt von Team-Präferenz ab: POM bietet stärkere Typisierung durch Rückgabetypen, Robot bietet flüssigere DSL-artige Tests. Für die FitnessApp mit ihren Feature-Modulen (Training, Schedule, Picker, Analytics) eignet sich ein **Screen Object pro Feature-Modul** mit konsistenten Accessibility-Identifiern.

### 1.2 Accessibility Identifiers als Fundament

Apple betont seit WWDC25 explizit: „Accessibility is the underlying framework that powers UI automation" [13]. Der `accessibilityIdentifier` ist der stabile Anker für Test-Queries — im Gegensatz zu `accessibilityLabel`, das sich mit Lokalisierung ändert [13]. Best Practice ist eine hierarchische Namenskonvention:

```swift
// Konvention: screen.elementType.purpose
exerciseCard.accessibilityIdentifier = "training.card.benchPress"
weightField.accessibilityIdentifier = "picker.input.weight"
saveButton.accessibilityIdentifier = "picker.button.save"
```

Für SwiftUI-Views ist `.accessibilityIdentifier()` der direkte Modifier. WWDC25 empfiehlt den **Accessibility Inspector** zum Verifizieren der Hierarchie [13].

### 1.3 Test-Isolation & App-State

XCTest erwartet, dass jeder Test von einem „known, predictable state" startet [1]. Da Teardown bei Crashes nicht garantiert ist, sollte der Zustand im **setUp** hergestellt werden — nicht im Teardown des vorherigen Tests [1].

`XCUIApplication` bietet dafür `launchArguments` und `launchEnvironment` [2]. Der gängige Ansatz: Ein Launch-Flag wie `--uitesting` schaltet in der App Mock-Daten ein und/oder setzt den Zustand zurück:

```swift
override func setUpWithError() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = ["--uitesting", "--resetState"]
    app.launchEnvironment = ["MOCK_API": "true"]
    app.launch()
}
```

Für Permission-basierte Tests bietet `XCUIApplication.resetAuthorizationStatus(for:)` einen offiziellen Weg, Berechtigungen zurückzusetzen [2].

### 1.4 Netzwerk-Isolation

Da XCUITest out-of-process läuft, kann der Testrunner keine URL-Sessions der App direkt stubben [13]. Zwei Strategien haben sich etabliert:

**Strategie A — App-seitige Feature-Flags:** Die App prüft `ProcessInfo.processInfo.arguments` oder `.environment` und tauscht den Netzwerk-Client gegen einen Mock. Einfach, keine externe Abhängigkeit, aber erfordert Produktionscode-Änderungen.

**Strategie B — Tunnel-Libraries:** **SBTUITestTunnel** [5][14] baut eine Brücke zwischen Test-Bundle und App, über die Requests intercepted, gestubt und überwacht werden können. Mächtiger, aber Integrationsaufwand (Framework in App und Test-Target einbinden). Alternativ können leichtgewichtige HTTP-Server wie **Swifter** oder **Peasy** [18] direkt im Test-Prozess laufen und die App per `launchEnvironment` auf `localhost` umleiten.

---

## 2. Emerging Trends [Confidence: High]

### 2.1 Xcode 16+ Wait-APIs

Xcode 16 hat zwei kritische Lücken geschlossen [6][7]:

- **`waitForNonExistence(withTimeout:)`** — Wartet, bis ein Element *verschwindet* (z.B. Loading-Spinner, Overlay). Vorher musste man Predicate-basierte Inversions manuell bauen.
- **`wait(for:toEqual:timeout:)`** — Wartet, bis eine Property (z.B. `.label`, `.value`) einen bestimmten Wert annimmt. Ideal für dynamische UI wie Zähler oder Status-Labels.

```swift
// Spinner-Verschwinden abwarten
let spinner = app.activityIndicators["loadingSpinner"]
spinner.waitForNonExistence(withTimeout: 10)

// Label-Wert abwarten
let setsLabel = app.staticTexts["training.label.sets"]
setsLabel.wait(for: \.label, toEqual: "3 / 3", timeout: 5)
```

Jesse Squires berichtet allerdings von Fällen, in denen `wait(for:toEqual:)` in Xcode 16 Betas einen zusätzlichen kurzen Wait benötigte, bevor es korrekt evaluierte [7]. Es empfiehlt sich, das Verhalten in der eigenen App zu validieren.

### 2.2 Swift Testing & XCUITest-Koexistenz

**Swift Testing** ist Apples neues Test-Framework mit Macro-basierter API (`@Test`, `#expect`), nativer Concurrency-Integration und paralleler Ausführung per Default [11]. Es ersetzt XCTest **nicht** für UI-Tests — WWDC25 positioniert beide Frameworks nebeneinander: Swift Testing für Unit- und Integrationstests, XCTest/XCUIAutomation für UI-Tests [13].

Die Koexistenz ist nahtlos: Bestehende XCTest-Tests laufen side-by-side mit Swift-Testing-Tests im selben Projekt [11]. Für die FitnessApp bedeutet das: Unit-Tests der ViewModels können schrittweise zu Swift Testing migriert werden, während XCUITests auf XCTest bleiben.

### 2.3 WWDC25: Record → Replay → Review

WWDC25 Session 344 [13] stellt einen modernisierten Workflow vor:

1. **Record** — Interaktionen aufzeichnen und als Code generieren lassen.
2. **Replay** — Über Test Plans auf verschiedenen Geräten, Sprachen und Konfigurationen abspielen.
3. **Review** — Ergebnisse mit Screenshots und Videos im Test-Report auswerten.

Der Fokus liegt auf **Accessibility Identifiers** als stabilem Fundament und dem **Accessibility Inspector** als Diagnose-Tool. UI-Automation importiert sich automatisch mit XCTest über das `XCUIAutomation`-Framework [13].

---

## 3. Critical Assessment [Confidence: High]

### 3.1 Synchronisation bleibt das Hauptproblem

Trotz der neuen Xcode-16-APIs ist die Synchronisation die häufigste Fehlerquelle in XCUITests. `XCTNSPredicateExpectation` hat ein dokumentiertes Polling-Problem: Timeouts unter 1.1 Sekunden schlagen unabhängig vom tatsächlichen Zustand fehl [8][9]. Die Ursache ist ein langer Sampling-Intervall, wie Apple selbst in WWDC 2018 „Testing Tips & Tricks" bestätigt hat [9]. Alternativen wie **Nimble's `toEventually`** bieten feineres Polling (~10ms Default) [9], erfordern aber eine externe Dependency.

### 3.2 Out-of-Process: Segen und Fluch

Das Out-of-Process-Modell macht Tests realistisch — sie interagieren wie echte User über die Accessibility-Hierarchie. Gleichzeitig verhindert es direkten Zugriff auf App-State, Netzwerk und Datenbank [13]. Jede Form von Mocking erfordert entweder Produktionscode-Änderungen (Feature-Flags) oder Framework-Integration (SBTUITestTunnel). Für die FitnessApp mit SwiftData-Persistence bedeutet das: Ein `--resetState`-Flag, das beim Launch die Datenbank leert und Seed-Daten einspielt, ist der pragmatischste Ansatz.

### 3.3 Lange Flows: Segmentierung vs. E2E

Lange Flows wie ein kompletter Workout-Durchlauf (Muscle Group → Exercise Picker → Training → Active Set → Timer → Completion → Schedule) sind wertvolle Smoke-Tests, aber inherent fragil und langsam. Die Konsens-Empfehlung aus der Community [3][4]:

- **Wenige E2E-Tests** für den kritischen Pfad (1-3 pro Haupt-Flow)
- **Viele fokussierte Tests** pro Screen/Feature
- **Komposierbare Helpers**, die E2E-Tests aus denselben Screen Objects zusammensetzen wie fokussierte Tests
- **Flow-Segmentierung**: Launch-Flags, die die App direkt in einen bestimmten Zustand bringen (z.B. „Training mit 3 Übungen bereits gestartet"), sodass ein Test den Active-Set-Flow testen kann, ohne den gesamten Vorlauf zu durchlaufen

```swift
// Segment-Test: Direkt in den Active-Set-State springen
func testActiveSetCompletion() throws {
    app.launchArguments += ["--preloadTrainingState", "--exerciseCount=3"]
    app.launch()

    ActiveSetScreen(app: app)
        .waitForScreen()
        .enterWeight(80)
        .confirmSet()
        .verifySetCompleted()
}
```

### 3.4 Architektur-Overhead bei kleinen Projekten

Ein Skeptiker würde anmerken: Page Objects und Robots bringen Abstraktions-Overhead, der bei wenigen Tests unverhältnismäßig ist. Das ist korrekt — für 5-10 Tests lohnt sich die Investition kaum. Ab ~20 Tests oder bei Teams mit mehreren Entwicklern amortisiert sich die Struktur jedoch schnell durch reduzierte Wartungskosten bei UI-Änderungen [3][4]. Für die FitnessApp mit ihren 7+ Feature-Modulen ist die Architektur gerechtfertigt.

### 3.5 UI-Interruption-Monitors: Häufig falsch verwendet

Ein verbreiteter Fehler ist die Verwendung von `addUIInterruptionMonitor` für *erwartete* Modals im Test-Flow (z.B. einen Permission-Dialog, den der Test auslöst). Apple stellt klar: Monitors sind nur für *unerwartete* UI gedacht, die den Test blockiert — etwa System-Alerts, die von Hintergrundprozessen kommen [6]. Erwartete Dialoge sollten direkt interagiert werden:

```swift
// FALSCH — Alert ist Teil des Flows
addUIInterruptionMonitor(withDescription: "Permission") { alert in
    alert.buttons["Allow"].tap()
    return true
}

// RICHTIG — Direkte Interaktion
app.buttons["Enable Notifications"].tap()
let alert = app.alerts.firstMatch
alert.buttons["Allow"].tap()
```

### 3.6 Speed-Optimierung

Die größten Hebel für schnellere UI-Tests [10]:

| Technik | Effekt |
|---------|--------|
| `UIView.setAnimationsEnabled(false)` via Launch-Flag | Eliminiert Animations-Wartezeit |
| `build-for-testing` + `test-without-building` | Trennt Build von Execution, ermöglicht Parallelisierung |
| Timing-basiertes Test-Splitting (CI) | Gleichmäßige Shard-Dauer statt zufälliger Verteilung |
| Simulator Pre-Boot + DerivedData-Caching | Reduziert Cold-Start-Overhead |
| Xcode Test Plans (`.xctestplan`) | Definierte Test-Subsets pro Pipeline-Stufe |

---

## 4. Action Plan

- [ ] **Screen Objects anlegen** — Pro Feature-Modul (Training, Schedule, Picker, Analytics) ein Screen Object/Robot mit typisierter Navigation und `waitForScreen()`-Protocol
- [ ] **Accessibility-Identifier-Konvention einführen** — Schema `screen.type.purpose` in allen SwiftUI-Views, validiert mit Accessibility Inspector
- [ ] **App-seitigen Reset-Mechanismus bauen** — `--uitesting` und `--resetState` Launch-Flags, die SwiftData-Container leeren und Seed-Daten laden
- [ ] **Animations deaktivieren** — Launch-Flag `--disableAnimations` → `UIView.setAnimationsEnabled(false)` im App-Start
- [ ] **Xcode 16 Wait-APIs adoptieren** — `waitForNonExistence` für Spinner/Overlays, `wait(for:toEqual:)` für dynamische Labels; `sleep()` komplett eliminieren
- [ ] **Lange Flows segmentieren** — Launch-Flags für Zustandssprünge (z.B. `--preloadTrainingState`), sodass Active-Set-Tests nicht den gesamten Flow durchlaufen müssen
- [ ] **3-5 E2E-Smoke-Tests** für kritische Pfade definieren (Workout-Completion, Schedule-Entry, Analytics-Navigation)
- [ ] **SBTUITestTunnel evaluieren** — Für Netzwerk-Stubbing ohne Produktionscode-Änderungen; alternativ Peasy/Swifter für leichtgewichtiges HTTP-Mocking
- [ ] **Test Plan erstellen** — `.xctestplan` mit Subset-Konfigurationen (Smoke, Full, Per-Feature) für CI-Integration
- [ ] **ViewInspector für ViewModel-nahe SwiftUI-Tests** — View-Logik unterhalb von XCUITest testen, um den E2E-Anteil zu reduzieren

## 5. Open Questions & Caveats

- **`wait(for:toEqual:)` Stabilität:** Jesse Squires berichtet von Fällen, in denen die API in Xcode 16 Betas einen zusätzlichen Wait benötigte [7]. Verhalten sollte mit der aktuellen Xcode-Version (17.x) validiert werden.
- **XCTNSPredicateExpectation Polling:** Das 1.1s-Minimum [9] könnte in neueren Xcode-Versionen verbessert worden sein — kein offizielles Statement von Apple dazu gefunden.
- **Swift Testing für UI-Tests:** Aktuell ist XCTest/XCUIAutomation der einzige Weg für UI-Tests. Ob Swift Testing in Zukunft XCUIAutomation integrieren wird, ist unklar — WWDC25 positioniert beide getrennt [13].
- **SBTUITestTunnel Xcode-Kompatibilität:** Das letzte GitHub-Release sollte gegen die verwendete Xcode-Version geprüft werden, bevor Integration geplant wird.
- **Quantitative Speed-Daten:** Konkrete Benchmarks (z.B. „Parallelisierung auf 4 Simulatoren reduziert Suite-Zeit um X%") sind in den Quellen dünn. Eigene Messungen mit der FitnessApp-Suite wären nötig.

## Methodology

**Depth:** Standard | **Subagents:** 3 Retrieval (Wave 1) + 1 Verification | **Waves:** 1 (Quality Gate nach Wave 1 bestanden — alle Areas ≥2 Quellen, kein Area rein [Low]) | **Sources collected:** 18 | **Citation spot-check:** 8 Claims geprüft, 7 SUPPORTED, 1 PARTIAL (Claim zu UI Interruption Monitors korrigiert — gilt für jede unerwartete blockierende UI, nicht nur Alerts) | **Outline changes:** Keine strukturellen Änderungen gegenüber Phase-1-Plan | **Report language:** Deutsch (Suchbegriffe mehrsprachig)

## Bibliography

[1] Apple Inc. — *Set Up and Tear Down State in Your Tests* — https://developer.apple.com/documentation/xctest/set-up-and-tear-down-state-in-your-tests — Accessed 2026-04-07 — Tier: 1
[2] Apple Inc. — *XCUIApplication* — https://developer.apple.com/documentation/xctest/xcuiapplication — Accessed 2026-04-07 — Tier: 1
[3] REI Co-op Engineering — *XCUITest Automation: Page Object Models for iOS Test Automation* — https://engineering.rei.com/mobile/xcuitest-page-object-models.html — Accessed 2026-04-07 — Tier: 2
[4] Jean Varloot (jhandguy) — *UI Testing in iOS - Robot Pattern* — https://jhandguy.github.io/posts/robot-pattern-ios/ — Accessed 2026-04-07 — Tier: 3
[5] Subito.it — *SBTUITestTunnel* — https://github.com/Subito-it/SBTUITestTunnel — Accessed 2026-04-07 — Tier: 2
[6] Apple Inc. — *Handling UI Interruptions* — https://developer.apple.com/documentation/xctest/handling-ui-interruptions — Accessed 2026-04-07 — Tier: 1
[7] Apple Inc. — *XCUIElement* — https://developer.apple.com/documentation/xctest/xcuielement — Accessed 2026-04-07 — Tier: 1
[8] Alex Ilyenko — *Waits in XCUITest* — https://alexilyenko.github.io/xcuitest-waiting/ — Accessed 2026-04-07 — Tier: 3
[9] Gio Lodi (mokacoding) — *XCTNSPredicateExpectation is slow, and what to do about it* — https://mokacoding.com/blog/xctnspredicateexpectation-slow/ — Accessed 2026-04-07 — Tier: 2
[10] CircleCI — *Speed up XCUITest execution with parallelism and test splitting* — https://circleci.com/blog/xcuitest-parallel-execution — Accessed 2026-04-07 — Tier: 2
[11] Apple Inc. — *Swift Testing* — https://developer.apple.com/xcode/swift-testing/ — Accessed 2026-04-07 — Tier: 1
[12] Jesse Squires — *UI testing improvements in Xcode 16* — https://www.jessesquires.com/blog/2024/07/09/uitest-improvements-in-xcode-16/ — Published 2024-07-09 — Tier: 2
[13] Apple Inc. (WWDC25) — *Record, replay, and review: UI automation with Xcode (Session 344)* — https://developer.apple.com/videos/play/wwdc2025/344/ — 2025 — Tier: 1
[14] Subito.it — *SBTUITestTunnel* (community references) — https://github.com/Subito-it/SBTUITestTunnel — Accessed 2026-04-07 — Tier: 2
[15] Point-Free — *swift-snapshot-testing* — https://github.com/pointfreeco/swift-snapshot-testing — Accessed 2026-04-07 — Tier: 2
[16] Alexey Naumov — *ViewInspector* — https://github.com/nalexn/ViewInspector — Accessed 2026-04-07 — Tier: 2
[17] Wesley de Groot — *Swift Package: XCUITestHelper* — https://wesleydegroot.nl/blog/swift-package-xcuitesthelper — Accessed 2026-04-07 — Tier: 3
[18] Kane Cheshire — *Peasy* — https://github.com/KaneCheshire/Peasy — Accessed 2026-04-07 — Tier: 2

## Source Extracts

### [1] Set Up and Tear Down State in Your Tests
- **Summary:** Dokumentiert XCTests Setup/Teardown-Reihenfolge. setUp() async throws → setUpWithError() → setUp() → Test → addTeardownBlock (LIFO) → tearDown(). Teardown ist nicht garantiert bei Crashes.
- **Key quotes:** "To consistently and reliably check that your code produces the correct results, tests need to start from a known, predictable state." / "Avoid preparing state for subsequent tests in the teardown methods."
- **Source type:** Official documentation
- **Credibility tier:** 1

### [2] XCUIApplication
- **Summary:** Definiert die API: launch(), launchArguments, launchEnvironment, wait(for:timeout:), terminate(), resetAuthorizationStatus(for:). Canonical hook für Test-Isolation.
- **Key quotes:** "Use this class to launch, monitor, and terminate your app in a UI test."
- **Source type:** Official documentation
- **Credibility tier:** 1

### [3] Page Object Models for iOS Test Automation
- **Summary:** POM für XCUITest: eine Klasse pro Screen, Navigation-Methoden mit Rückgabetyp des nächsten Screens, SynchronizedView-Protocol, Locators in Enums, Page Components für wiederverwendbare UI-Units.
- **Key quotes:** "In user interface automation, everything begins and ends with definite synchronization between the application under test (AUT) and the automation that drives it." / "RULE #1: Fail Fast with Detailed Diagnostics"
- **Source type:** Engineering blog (established company)
- **Credibility tier:** 2

### [4] Robot Pattern iOS
- **Summary:** Robot Pattern für XCTest: Tests drücken Intent aus, Robots kapseln Element-Queries. Fluentes Chaining mit @discardableResult. Cross-Robot Handoffs für Screen-Übergänge.
- **Key quotes:** "Common UI Tests are mixing the What and the How altogether, in one place." / "The idea … is to separate in a UI Test the What from the How."
- **Source type:** Personal blog (practitioner)
- **Credibility tier:** 3

### [5] SBTUITestTunnel
- **Summary:** OSS-Library für Network-Stubbing/-Monitoring in XCUITests via Tunnel zwischen Test-Bundle und App. Löst das Out-of-Process-Problem für Netzwerk-Isolation.
- **Key quotes:** "Enable network mocks and more in UI Tests."
- **Source type:** Open-source project
- **Credibility tier:** 2

### [6] Handling UI Interruptions
- **Summary:** addUIInterruptionMonitor für unerwartete blockierende UI. LIFO-Stack, Return true/false. NICHT für erwartete Workflow-Modals verwenden.
- **Key quotes:** "When an alert or other modal UI is an expected part of the test workflow, don't write a UI interruption monitor."
- **Source type:** Official documentation
- **Credibility tier:** 1

### [7] XCUIElement
- **Summary:** Wait-APIs: waitForExistence(timeout:), waitForNonExistence(timeout:), wait(for:toEqual:timeout:). Canonical replacement für sleep().
- **Key quotes:** "Waits the specified amount of time for an element to exist."
- **Source type:** Official documentation
- **Credibility tier:** 1

### [8] Waits in XCUITest
- **Summary:** Erklärt XCTest Expectation-Typen (KVO, Notification, Predicate). XCTWaiter für nicht-fatale Waits. Custom XCTestExpectation für Callback-basiertes Async.
- **Key quotes:** "XCTNSPredicateExpectation - in my opinion the main expectation in functional testing."
- **Source type:** Personal blog (technical)
- **Credibility tier:** 3

### [9] XCTNSPredicateExpectation is slow
- **Summary:** Benchmark: Timeouts ≤0.9s scheitern immer, 1.0s flaky, ≥1.1s zuverlässig. Ursache: Polling mit langem Intervall. Alternative: Nimble toEventually mit ~10ms Polling.
- **Key quotes:** "XCTNSPredicateExpectation requires a timeout of at least 1.1 seconds or it will fail regardless of whether the behavior under test occurred."
- **Source type:** Industry blog (well-known practitioner)
- **Credibility tier:** 2

### [10] Speed up XCUITest execution
- **Summary:** CI-Rezept: build-for-testing + test-without-building, parallele Jobs, Timing-basiertes Splitting, Simulator Pre-Boot, DerivedData-Caching.
- **Key quotes:** "Timing-based test splitting gives you the lowest possible test time for the available compute power."
- **Source type:** Vendor blog (CI/CD)
- **Credibility tier:** 2

### [11] Swift Testing
- **Summary:** Macro-basierte API (@Test, #expect), parallele Ausführung per Default, Swift Concurrency Integration. Koexistenz mit XCTest.
- **Key quotes:** "All tests integrate seamlessly with Swift Concurrency and run in parallel by default." / "If you already have tests written using XCTest, you can run them side-by-side."
- **Source type:** Official documentation
- **Credibility tier:** 1

### [12] UI testing improvements in Xcode 16
- **Summary:** Zwei neue APIs: waitForNonExistence(withTimeout:) und wait(for:toEqual:timeout:). Praktische Probleme mit wait(for:toEqual:) in Betas dokumentiert.
- **Key quotes:** "Finally! This is such a welcome change."
- **Source type:** Industry blog (well-known iOS developer)
- **Credibility tier:** 2

### [13] WWDC25 Session 344
- **Summary:** Record → Replay → Review Workflow. XCUIAutomation powered by Accessibility. Accessibility Identifiers für stabile Queries. Swift Testing + XCTest nebeneinander.
- **Key quotes:** "Accessibility is the underlying framework that powers UI automation." / "Inside Xcode, we have two testing frameworks: Swift Testing and XCTest."
- **Source type:** Official conference session
- **Credibility tier:** 1

### [14] SBTUITestTunnel (community)
- **Summary:** Ergänzende Community-Referenzen zu SBTUITestTunnel. Feature-Set: Stub, Monitor, Block requests. SBTUITunneledApplication als Drop-in.
- **Key quotes:** —
- **Source type:** Community references
- **Credibility tier:** 2

### [15] swift-snapshot-testing
- **Summary:** Snapshot-Library für Views, View Controllers, Encodable Values. assertSnapshot für schnelle Regressionstests. Kein Ersatz für E2E-Tests.
- **Key quotes:** "Delightful Swift snapshot testing."
- **Source type:** Open-source project (established company)
- **Credibility tier:** 2

### [16] ViewInspector
- **Summary:** SwiftUI View Inspection für Unit-Tests. Traverse Views, lese State, trigger Actions. Nicht XCUITest-kompatibel (in-process).
- **Key quotes:** —
- **Source type:** Open-source project
- **Credibility tier:** 2

### [17] XCUITestHelper
- **Summary:** SPM-Package mit Extensions für XCUIApplication und XCUIElement. Waits, Navigation, Language Setup.
- **Key quotes:** —
- **Source type:** Personal blog (technical)
- **Credibility tier:** 3

### [18] Peasy
- **Summary:** Pure-Swift Mock-HTTP-Server für iOS/macOS UI-Tests. Läuft im Test-Prozess, kein externer Server nötig.
- **Key quotes:** "A pure Swift mock server for embedding and running directly within iOS/macOS UI tests."
- **Source type:** Open-source project
- **Credibility tier:** 2
