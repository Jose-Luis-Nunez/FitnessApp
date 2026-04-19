# T5 — Pilot: `ExerciseCardModelView` in FitnessPersistenceUI

> **Layer**: Pilot-Migration
> **Vorbedingung**: T4 (Package)
> **Blockiert**: T7 (TrainingView)
> **Aufwand**: ~90 min

## Ziel

Eine neue View `ExerciseCardModelView` in `FitnessPersistenceUI` die direkt `@Bindable ExerciseModel` konsumiert statt `Exercise`-struct + `ExerciseCardViewModel`-Snapshot. Macht den ersten Bug-1-Test (`cardVariantUpdatesAfterFinish`) grün — sobald T7 die View einsetzt.

## Kontext

`ExerciseCardContainerView` heute (`Packages/FitnessExercise/Sources/FitnessExercise/ExerciseCardContainerView.swift`):
- Resolves `CardVariant` aus `isCompleted`, `isActiveSetVisible`, `activeExerciseId`
- Rendert `InactiveCardView`, `ActiveCardView`, `IdleActiveCardView`

Diese drei konkreten Card-Variants bleiben in `FitnessExercise` (kein SwiftData-Import nötig). Nur der Container wird in `FitnessPersistenceUI` neu gebaut.

## Schritte

### 1. ExerciseCardModelView (neue View)

`Datei: Packages/FitnessPersistenceUI/Sources/FitnessPersistenceUI/ExerciseCardModelView.swift`

```swift
import SwiftUI
import SwiftData
@_spi(PersistenceUI) import FitnessStorage
import FitnessCore
import FitnessExercise  // für InactiveCardView, ActiveCardView, IdleActiveCardView, CardVariant

public struct ExerciseCardModelView: View {
    @Bindable public var model: ExerciseModel
    public let activeExerciseId: UUID?
    public let isActiveSetVisible: Bool
    public let onTap: () -> Void
    public let onActivate: () -> Void
    public let onLog: () -> Void
    // ... weitere Callbacks die heute via ExerciseCardViewModel gehen

    public init(
        model: ExerciseModel,
        activeExerciseId: UUID?,
        isActiveSetVisible: Bool,
        onTap: @escaping () -> Void,
        onActivate: @escaping () -> Void,
        onLog: @escaping () -> Void
    ) {
        self.model = model
        self.activeExerciseId = activeExerciseId
        self.isActiveSetVisible = isActiveSetVisible
        self.onTap = onTap
        self.onActivate = onActivate
        self.onLog = onLog
    }

    public var body: some View {
        // Bridge: erzeuge eine struct-Sicht für die existierenden konkreten Card-Views.
        // Wichtig: Lese alle Felder direkt von `model`, NICHT zwischenspeichern.
        let exercise = model.toDomain()
        let variant = resolveVariant(
            isCompleted: model.isCompleted,
            isActive: activeExerciseId == model.id,
            isActiveSetVisible: isActiveSetVisible
        )

        switch variant {
        case .completed:
            InactiveCardView(exercise: exercise, onTap: onTap)
        case .active:
            ActiveCardView(exercise: exercise, onTap: onTap, onLog: onLog)
        case .idle:
            IdleActiveCardView(exercise: exercise, onActivate: onActivate, onTap: onTap)
        }
    }
}
```

`resolveVariant` aus `ExerciseCardContainerView.swift` extrahieren als `public func` in FitnessExercise oder neu hier — abhängig von Sichtbarkeit in der existierenden Datei.

### 2. CardVariant-Resolver public machen

`Datei: Packages/FitnessExercise/Sources/FitnessExercise/CardVariant.swift` (neu, oder Verschiebung aus ExerciseCardContainerView)

```swift
import FitnessCore

public enum CardVariant {
    case completed
    case active
    case idle
}

public func resolveVariant(
    isCompleted: Bool,
    isActive: Bool,
    isActiveSetVisible: Bool
) -> CardVariant {
    // Logik 1:1 aus ExerciseCardContainerView extrahiert
    if isCompleted { return .completed }
    if isActive && isActiveSetVisible { return .active }
    return .idle
}
```

### 3. Tests für ExerciseCardModelView

`Datei: Packages/FitnessPersistenceUI/Tests/FitnessPersistenceUITests/ExerciseCardModelViewTests.swift`

```swift
import Testing
import SwiftUI
import SwiftData
@_spi(PersistenceUI) import FitnessStorage
@testable import FitnessPersistenceUI
import FitnessExercise
import FitnessCore

@Suite("ExerciseCardModelView reflects @Model mutations")
@MainActor
struct ExerciseCardModelViewTests {

    @Test("Variant computed from model.isCompleted is .completed when true")
    func variantWhenCompleted() throws {
        let stack = try InMemoryStorageStack()
        let workout = WorkoutModel(id: UUID(), name: "W")
        let model = ExerciseModel(id: UUID(), workoutId: workout.id, name: "X",
                                   category: "arms", sets: 1, reps: 1, weight: 0,
                                   isCompleted: true, sortOrder: 0)
        let ctx = ModelContext(stack.container)
        ctx.insert(workout); ctx.insert(model); try ctx.save()

        let variant = resolveVariant(isCompleted: model.isCompleted, isActive: false, isActiveSetVisible: false)
        #expect(variant == .completed)
    }

    @Test("After mutation model.isCompleted=true, variant changes")
    func variantUpdatesOnMutation() throws {
        let stack = try InMemoryStorageStack()
        let workout = WorkoutModel(id: UUID(), name: "W")
        let model = ExerciseModel(id: UUID(), workoutId: workout.id, name: "X",
                                   category: "arms", sets: 1, reps: 1, weight: 0,
                                   isCompleted: false, sortOrder: 0)
        let ctx = ModelContext(stack.container)
        ctx.insert(workout); ctx.insert(model); try ctx.save()

        #expect(resolveVariant(isCompleted: model.isCompleted, isActive: false, isActiveSetVisible: false) == .idle)

        model.isCompleted = true
        try ctx.save()
        #expect(resolveVariant(isCompleted: model.isCompleted, isActive: false, isActiveSetVisible: false) == .completed)
    }
}
```

(Diese Tests prüfen die Logik. Der Beweis dass SwiftUI auf Mutation reagiert kommt aus Bug-1-Invariant-Test in T2 nach T7.)

### 4. Build + Tests

```bash
cd ~/Documents/repo/FitnessApp/Packages/FitnessPersistenceUI && \
DEVELOPER_DIR=/Users/jose.nunez/Downloads/Xcode.app/Contents/Developer \
PATH="/Users/jose.nunez/Downloads/Xcode.app/Contents/Developer/usr/bin:$PATH" \
xcodebuild test -scheme FitnessPersistenceUI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -skipMacroValidation 2>&1 | tail -30
```

### 5. Reviewing-code-changes Skill anwenden

- §13b Reactive over Polling — neue View nutzt `@Bindable`, kein Counter ✓
- §13h Duplicate Domain-State Holders — neue View hält keinen `@State`-VM-Snapshot ✓
- §14 SwiftData Predicate Anti-Patterns — keine `#Predicate` in dieser View ✓
- AppStyle-Konventionen — verifizieren dass alle benutzten Card-Views noch AppStyle nutzen

## Definition of Done

- [ ] `ExerciseCardModelView.swift` in FitnessPersistenceUI existiert, kompiliert
- [ ] `CardVariant`/`resolveVariant` als `public` API in FitnessExercise extrahiert
- [ ] Tests in `ExerciseCardModelViewTests` grün
- [ ] Existierender `ExerciseCardContainerView` bleibt unverändert (parallel) — wird erst in T7 obsolet
- [ ] Reviewing-code-changes Skill durchlaufen, Stamp geschrieben
- [ ] Commit-Message: "T5: pilot ExerciseCardModelView in FitnessPersistenceUI per ADR-0001"

## Akzeptanzkriterien

`ExerciseCardModelView` ist verfügbar und nutzt `@Bindable ExerciseModel` als Datenquelle. Sie wird in T7 die alte snapshot-basierte Card im TrainingView ersetzen.
