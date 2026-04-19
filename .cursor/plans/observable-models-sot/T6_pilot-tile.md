# T6 — Pilot: `CategoryTileModelView` mit `@Query`

> **Layer**: Pilot-Migration
> **Vorbedingung**: T4 (Package), T3 (workoutId Schema)
> **Blockiert**: T7
> **Aufwand**: ~90 min

## Ziel

Neue `CategoryTileModelView` in `FitnessPersistenceUI` die ihre "X of Y"-Anzeige direkt aus einem `@Query<ExerciseModel>`-Predicate berechnet. Macht Bug-2-Invariant-Test grün — sobald `MuscleCategorySelectionView` sie einsetzt.

## Kontext

Heute (`Packages/FitnessExercise/Sources/FitnessExercise/CategoryTileView.swift`):
```swift
public struct CategoryTileView: View {
    let group: MuscleCategoryGroup
    @Bindable var viewModel: MuscleCategorySelectionViewModel  // VM-Cache als Quelle
    var body: some View {
        Text("\(viewModel.getExerciseCount(for: group).active) of \(viewModel.getExerciseCount(for: group).total)")
    }
}
```

Plan: Predicate auf `@Model` direkt, kein VM-Cache als Daten-Mirror.

## Schritte

### 1. CategoryTileModelView

`Datei: Packages/FitnessPersistenceUI/Sources/FitnessPersistenceUI/CategoryTileModelView.swift`

```swift
import SwiftUI
import SwiftData
@_spi(PersistenceUI) import FitnessStorage
import FitnessCore
import FitnessUI  // für AppStyle

public struct CategoryTileModelView: View {
    public let group: MuscleCategoryGroup
    public let workoutId: UUID
    public let hasActiveSetForCategory: Bool
    public let onTap: () -> Void

    @Query private var exercises: [ExerciseModel]

    public init(
        group: MuscleCategoryGroup,
        workoutId: UUID,
        hasActiveSetForCategory: Bool,
        onTap: @escaping () -> Void
    ) {
        self.group = group
        self.workoutId = workoutId
        self.hasActiveSetForCategory = hasActiveSetForCategory
        self.onTap = onTap

        let raw = group.rawValue
        // Anti-Pattern §14a vermieden via denormalisiertem workoutId aus T3
        _exercises = Query(
            filter: #Predicate<ExerciseModel> {
                $0.workoutId == workoutId && $0.category == raw
            },
            sort: [SortDescriptor(\.sortOrder)]
        )
    }

    public var body: some View {
        let total = exercises.count
        let active = exercises.lazy.filter { !$0.isCompleted }.count

        Button(action: onTap) {
            // Konsistent mit existierendem CategoryTileView Layout
            VStack(alignment: .leading) {
                Text(group.localizedName)
                    .font(AppStyle.Font.tileTitle)
                Text("\(active) of \(total)")
                    .font(AppStyle.Font.tileSubtitle)
                    .foregroundStyle(AppStyle.Color.tileSubtitle)
                if hasActiveSetForCategory {
                    // active indicator
                }
            }
            .padding(AppStyle.Spacing.tile)
            .background(AppStyle.Color.tileBackground)
            .cornerRadius(AppStyle.Radius.tile)
        }
        .buttonStyle(.plain)
    }
}
```

(Layout-Code 1:1 aus heutigem `CategoryTileView` übernehmen — AppStyle-Tokens beibehalten.)

### 2. View-Identity in Parent garantieren

Der Parent (in T7-Phase: `MuscleCategorySelectionView`) muss bei Workout-Wechsel die Tiles neu identifizieren:

```swift
ForEach(MuscleCategoryGroup.allCases, id: \.self) { group in
    CategoryTileModelView(
        group: group,
        workoutId: currentWorkoutId,
        hasActiveSetForCategory: viewModel.hasActiveSetForCategory(group),
        onTap: { /* navigate */ }
    )
    .id(currentWorkoutId)  // <-- Anti-Pattern §14d vermieden
}
```

(In T7 umsetzen, hier nur als Hinweis dokumentiert.)

### 3. Tests für CategoryTileModelView

`Datei: Packages/FitnessPersistenceUI/Tests/FitnessPersistenceUITests/CategoryTileModelViewTests.swift`

```swift
import Testing
import SwiftUI
import SwiftData
@_spi(PersistenceUI) import FitnessStorage
@testable import FitnessPersistenceUI
import FitnessCore

@Suite("CategoryTileModelView count from @Query")
@MainActor
struct CategoryTileModelViewTests {

    @Test("Count reflects active and total exercises in category for workout")
    func countMatchesData() throws {
        let stack = try InMemoryStorageStack()
        let workoutId = UUID()
        let workout = WorkoutModel(id: workoutId, name: "W")
        let ctx = ModelContext(stack.container)
        ctx.insert(workout)
        for i in 0..<3 {
            let m = ExerciseModel(id: UUID(), workoutId: workoutId, name: "E\(i)",
                                   category: "arms", sets: 1, reps: 1, weight: 0,
                                   isCompleted: i == 0, sortOrder: i)
            m.workout = workout
            ctx.insert(m)
        }
        try ctx.save()

        // Query-Logik direkt verifizieren (statt View-rendering):
        var fd = FetchDescriptor<ExerciseModel>(
            predicate: #Predicate { $0.workoutId == workoutId && $0.category == "arms" }
        )
        let fetched = try ctx.fetch(fd)
        #expect(fetched.count == 3)
        #expect(fetched.filter { !$0.isCompleted }.count == 2)
    }

    @Test("After mutation, query count drops in same context")
    func countDropsAfterMutation() throws {
        let stack = try InMemoryStorageStack()
        let workoutId = UUID()
        let ctx = ModelContext(stack.container)
        let w = WorkoutModel(id: workoutId, name: "W"); ctx.insert(w)
        let e = ExerciseModel(id: UUID(), workoutId: workoutId, name: "X",
                               category: "arms", sets: 1, reps: 1, weight: 0,
                               isCompleted: false, sortOrder: 0)
        e.workout = w; ctx.insert(e); try ctx.save()

        var fd = FetchDescriptor<ExerciseModel>(
            predicate: #Predicate { $0.workoutId == workoutId && $0.category == "arms" && !$0.isCompleted }
        )
        #expect(try ctx.fetch(fd).count == 1)

        e.isCompleted = true
        try ctx.save()
        #expect(try ctx.fetch(fd).count == 0)
    }
}
```

### 4. Build + Tests

```bash
cd ~/Documents/repo/FitnessApp/Packages/FitnessPersistenceUI && \
DEVELOPER_DIR=/Users/jose.nunez/Downloads/Xcode.app/Contents/Developer \
PATH="/Users/jose.nunez/Downloads/Xcode.app/Contents/Developer/usr/bin:$PATH" \
xcodebuild test -scheme FitnessPersistenceUI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -skipMacroValidation 2>&1 | tail -30
```

### 5. Reviewing-code-changes Skill

- §14a Optional-Chain in Predicate — vermieden durch `workoutId` ✓
- §14c PersistentIdentifier-Vergleich — wir nutzen `id == UUID`-äquivalent ✓
- §14d `@Query` ohne View-Identity unter dynamischem Filter — dokumentiert in §2-Hinweis, in T7 umzusetzen
- §13h Duplicate Domain-State Holders — Tile holt aus `@Query`, kein VM-Cache ✓

## Definition of Done

- [ ] `CategoryTileModelView.swift` in FitnessPersistenceUI existiert, kompiliert
- [ ] Tests in `CategoryTileModelViewTests` grün
- [ ] Layout 1:1 zum heutigen `CategoryTileView` (AppStyle-konsistent)
- [ ] T7-Voraussetzung dokumentiert: Parent muss `.id(currentWorkoutId)` setzen
- [ ] Reviewing-code-changes Skill durchlaufen, Stamp geschrieben
- [ ] Commit-Message: "T6: pilot CategoryTileModelView with @Query per ADR-0001/0002"

## Akzeptanzkriterien

`CategoryTileModelView` ist verfügbar. Bei Mutation eines `ExerciseModel.isCompleted` aktualisiert die Tile-Anzeige automatisch (im SwiftUI-Tick), ohne dass ein VM `refreshExercises()` aufrufen muss.
