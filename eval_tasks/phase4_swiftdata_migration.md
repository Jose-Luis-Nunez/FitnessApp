# Phase 4: Persistence — SwiftData Migration

## Prerequisite
Phase 3 (Use Cases) must be complete and building.

## Goal
Replace JSON file + UserDefaults persistence with SwiftData.
This is the largest phase — plan for incremental migration with a feature flag.

## Current State
- **Workouts**: Stored via `UserDefaults` (`JSONEncoder`/`JSONDecoder`) in `WorkoutStorageService`
- **Exercises**: Stored as JSON files per workout+category in `ExerciseStorageService`
- **Analytics**: Stored as JSON files per exercise in `AnalyticsStorageService`
- **Anti-pattern**: `Workout.exerciseData: [String: Any]` — untyped dictionary

## Steps

### 1. Create FitnessStorage SwiftData models

Create `@Model` classes in `Packages/FitnessStorage/Sources/FitnessStorage/Models/`:

```swift
// WorkoutModel.swift
@Model
final class WorkoutModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var selectedCategories: [String]  // MuscleCategoryGroup raw values
    var lastModified: Date
    var isDefault: Bool
    @Relationship(deleteRule: .cascade) var exercises: [ExerciseModel]
}

// ExerciseModel.swift
@Model
final class ExerciseModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var weight: Double
    var reps: Int
    var sets: Int
    var seatSetting: String?
    var noSeats: Bool
    var isCompleted: Bool
    var iconName: String
    var category: String  // MuscleCategoryGroup raw value
    var workout: WorkoutModel?
}

// AnalyticsEntryModel.swift
@Model
final class AnalyticsEntryModel {
    @Attribute(.unique) var id: UUID
    var exerciseId: UUID
    var date: Date
    @Relationship(deleteRule: .cascade) var setProgressEntries: [SetProgressModel]
}

// SetProgressModel.swift
@Model
final class SetProgressModel {
    var status: String  // SetStatus raw value
    var currentReps: Int
    var weight: Double
    var entry: AnalyticsEntryModel?
}
```

### 2. Create DTO mapping

Add extensions to map between SwiftData `@Model` types and `FitnessCore` domain entities:

```swift
// WorkoutModel+Mapping.swift
extension WorkoutModel {
    func toDomain() -> Workout { ... }
    static func from(_ workout: Workout) -> WorkoutModel { ... }
}

// ExerciseModel+Mapping.swift  
extension ExerciseModel {
    func toDomain() -> Exercise { ... }
    static func from(_ exercise: Exercise) -> ExerciseModel { ... }
}
```

Domain entities in `FitnessCore` remain plain structs (no SwiftData dependency).

### 3. Rewrite storage services using ModelContext

Replace file-based implementations with SwiftData queries:

- `WorkoutStorageService` — Replace `UserDefaults` encode/decode with `ModelContext` fetch/insert/delete
- `ExerciseStorageService` — Replace JSON file read/write with `ModelContext` queries filtered by workout + category
- `AnalyticsStorageService` — Replace JSON file read/write with `ModelContext` queries filtered by exerciseId

Each service receives `ModelContext` via DI (Factory).

### 4. Remove `Workout.exerciseData: [String: Any]`

This untyped dictionary is an anti-pattern. With SwiftData:
- Exercise data is stored in `ExerciseModel` with proper types
- The `exerciseData` property and its encode/decode logic can be removed from `Workout`
- Remove `updateExerciseData(for:key:data:)` and `getExerciseData(for:key:)` from `WorkoutStorageService`

### 5. One-time data migration

Create `DataMigrationService`:
1. Check if migration has been performed (UserDefaults flag)
2. Read all existing JSON files and UserDefaults data
3. Create corresponding SwiftData models
4. Save to ModelContext
5. Set migration-complete flag
6. (Optional) Delete old JSON files after successful migration

Run migration in `FitnessAppApp.init()` before any other service access.

### 6. Configure ModelContainer

In `FitnessAppApp`:
```swift
@main
struct FitnessAppApp: App {
    let modelContainer: ModelContainer

    init() {
        let schema = Schema([WorkoutModel.self, ExerciseModel.self, AnalyticsEntryModel.self, SetProgressModel.self])
        modelContainer = try! ModelContainer(for: schema)
        // Run migration if needed
        DataMigrationService.migrateIfNeeded(context: modelContainer.mainContext)
    }

    var body: some Scene {
        WindowGroup { ... }
            .modelContainer(modelContainer)
    }
}
```

## Verification
- All data persists correctly after migration
- Old JSON files can be read and migrated successfully
- New data is written to SwiftData only
- `Workout.exerciseData` property removed
- `try?` in encode/decode replaced with proper error handling
- App builds and all existing functionality works identically
- Performance: no regression on large datasets

## Risks
- Data loss during migration — mitigate with backup and migration flag
- Schema versioning — plan for `VersionedSchema` from the start
- This phase touches all storage services — thorough testing required
