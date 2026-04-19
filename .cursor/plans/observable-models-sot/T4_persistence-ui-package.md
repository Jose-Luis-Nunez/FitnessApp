# T4 — `FitnessPersistenceUI` Package skeleton

> **Layer**: Architektur — neues SPM-Modul
> **Vorbedingung**: T3 (Schema-Migration)
> **Blockiert**: T5 (Card), T6 (Tile)
> **Aufwand**: ~45 min

## Ziel

Neues SPM-Package `FitnessPersistenceUI` als einzige Stelle die `import SwiftData` + `@Query`/`@Bindable` Code enthält (siehe ADR-0002). Skeleton ohne Views — die kommen in T5/T6/T7.

## Schritte

### 1. Package erzeugen

`Datei: Packages/FitnessPersistenceUI/Package.swift`

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FitnessPersistenceUI",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FitnessPersistenceUI", targets: ["FitnessPersistenceUI"])
    ],
    dependencies: [
        .package(path: "../FitnessCore"),
        .package(path: "../FitnessStorage"),
        .package(path: "../FitnessUI")  // für AppStyle / shared UI primitives
    ],
    targets: [
        .target(
            name: "FitnessPersistenceUI",
            dependencies: [
                "FitnessCore",
                "FitnessStorage",
                "FitnessUI"
            ]
        ),
        .testTarget(
            name: "FitnessPersistenceUITests",
            dependencies: [
                "FitnessPersistenceUI",
                "FitnessStorage",
                "FitnessCore"
            ]
        )
    ]
)
```

### 2. Skeleton-Source

`Datei: Packages/FitnessPersistenceUI/Sources/FitnessPersistenceUI/FitnessPersistenceUI.swift`

```swift
// FitnessPersistenceUI
//
// Single import surface for SwiftData + SwiftUI integration.
// Hosts `@Query`/`@Bindable`-driven views for `ExerciseModel`,
// `WorkoutModel`, etc. See docs/adr/0002-persistence-ui-package.md.

import SwiftUI
import SwiftData

public enum FitnessPersistenceUI {}
```

### 3. SPI-Marker auf `FitnessStorage`-Models

ADR-0002 ist eindeutig: `@_spi(PersistenceUI)` ist die **bewusst gewählte beste
Lösung** (compiler-enforced, Apple-first-party, keine Wrapper). Wrapper-Optionen
wurden geprüft und verworfen (siehe ADR-0002 § "Bewertung", Option D).

`Datei: Packages/FitnessStorage/Sources/FitnessStorage/Models/ExerciseModel.swift`

```swift
@_spi(PersistenceUI)
@Model
public final class ExerciseModel {
    @_spi(PersistenceUI) public var id: UUID
    @_spi(PersistenceUI) public var workoutId: UUID
    @_spi(PersistenceUI) public var name: String
    @_spi(PersistenceUI) public var category: String
    @_spi(PersistenceUI) public var sets: Int
    @_spi(PersistenceUI) public var reps: Int
    @_spi(PersistenceUI) public var weight: Double
    @_spi(PersistenceUI) public var isCompleted: Bool
    @_spi(PersistenceUI) public var sortOrder: Int
    @_spi(PersistenceUI) public var workout: WorkoutModel?
    // ...
}
```

(`@_spi` macht den Symbol für andere Module sichtbar, aber nur wenn diese Module
mit `@_spi(PersistenceUI) import FitnessStorage` importieren — schmälere
Oberfläche als `public`.)

In `FitnessPersistenceUI`:
```swift
@_spi(PersistenceUI) import FitnessStorage
```

**Wenn `@_spi(PersistenceUI)` in Kombination mit dem `@Model`-Macro einen Compiler-
Bug auslöst** (gegen aktuelle Xcode-Version verifizieren bevor T4 startet — siehe
ADR-0002 § "Lock-in / Exit-Strategie"): das **ist** der Trigger den ADR-0002
explizit nennt. Bug bei Apple melden + temporär `public` mit Lint-Rule
(`disallow-import-fitness-storage-outside-persistence-ui`) als gleichwertige aber
weniger elegante Variante einsetzen — und den Workaround in einem ergänzenden
ADR-Update dokumentieren. Nicht stillschweigend auf `public` ausweichen.

### 4. Test-Target Setup

`Datei: Packages/FitnessPersistenceUI/Tests/FitnessPersistenceUITests/PackageSetupTests.swift`

```swift
import Testing
import SwiftData
@_spi(PersistenceUI) import FitnessStorage
@testable import FitnessPersistenceUI

@Suite("Package setup")
@MainActor
struct PackageSetupTests {
    @Test("Can build in-memory ModelContainer with full schema")
    func canCreateContainer() throws {
        let stack = try InMemoryStorageStack()
        #expect(stack.container.schema.entities.count >= 5)
    }

    @Test("Can fetch ExerciseModel from FitnessPersistenceUI module")
    func canFetchModel() throws {
        let stack = try InMemoryStorageStack()
        let context = ModelContext(stack.container)
        let fd = FetchDescriptor<ExerciseModel>()
        _ = try context.fetch(fd)  // schould not throw
    }
}
```

### 5. App-Target & Project Integration

`Datei: FitnessApp.xcodeproj` — Package-Referenz ergänzen (über Xcode Add Package Dependency dialog auf `Packages/FitnessPersistenceUI` oder direkt im project.pbxproj).

App-Target depends auf `FitnessPersistenceUI` (für T7).

### 6. Architektur-Doc updaten

`Datei: .cursor/references/architecture-documentation.md` — neues Package in Feature-Map / Package-Liste eintragen mit Verweis auf ADR-0002.

### 7. Build prüfen

```bash
cd ~/Documents/repo/FitnessApp/Packages/FitnessPersistenceUI && \
DEVELOPER_DIR=/Users/jose.nunez/Downloads/Xcode.app/Contents/Developer \
PATH="/Users/jose.nunez/Downloads/Xcode.app/Contents/Developer/usr/bin:$PATH" \
xcodebuild build -scheme FitnessPersistenceUI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -skipMacroValidation 2>&1 | tail -20

cd ~/Documents/repo/FitnessApp && \
DEVELOPER_DIR=/Users/jose.nunez/Downloads/Xcode.app/Contents/Developer \
xcodebuild build -scheme FitnessApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' 2>&1 | tail -20
```

## Definition of Done

- [ ] `Packages/FitnessPersistenceUI/Package.swift` existiert mit korrekten Dependencies
- [ ] Skeleton-Source kompiliert
- [ ] `ExerciseModel` (und ggf. weitere Models) sind aus `FitnessPersistenceUI` zugreifbar (via `@_spi` oder `public`)
- [ ] Test-Target läuft grün
- [ ] FitnessApp-Target depends auf FitnessPersistenceUI und builds grün
- [ ] `architecture-documentation.md` zeigt das neue Package
- [ ] Stamp geschrieben
- [ ] adr-required.sh Hook lässt durch (neues Package = Trigger 5, ADR-0002 ist im Commit verlinkt)
- [ ] Commit-Message: "T4: scaffold FitnessPersistenceUI package per ADR-0002"

## Akzeptanzkriterien

`FitnessPersistenceUI` ist ein vollwertiges Package, kann SwiftData-Code enthalten, und das App-Target nutzt es. Keine weiteren Packages außer FitnessPersistenceUI dürfen `import SwiftData` haben (verifiziert via `rg`).

```bash
rg -l 'import SwiftData' Packages | rg -v 'FitnessStorage|FitnessPersistenceUI'
# Erwartung: leer
```
