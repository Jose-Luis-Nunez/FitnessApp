import Foundation
import SwiftData
import Testing
import FitnessCore
import FitnessTestSupport
@_spi(PersistenceUI) @testable import FitnessStorage

/// Tests for the SchemaV1 → SchemaV2 migration introduced in T3 (ADR-0005).
///
/// We exercise the **real container-version transition** (writing rows in V1
/// form, then opening the same store as V2 with `AppMigrationPlan`), not just
/// the `didMigrate` closure in isolation — that's what makes this a meaningful
/// regression guard for the migration path users will run on first launch
/// after the V2 release.
@MainActor
@Suite("V1 → V2 migration backfills workoutId from workout.id", .serialized, .tags(.integration))
struct MigrationV1toV2Tests {

    /// Per-test scratch directory so each test gets its own SQLite store; the
    /// migration runs once per container-open, so we MUST start clean.
    private func makeStoreURL() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "MigrationV1toV2-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "store.sqlite")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    @Test("Live ExerciseModel.from(... workout:) propagates workoutId")
    func liveFromHelperSetsWorkoutId() throws {
        let workout = WorkoutModel(
            id: UUID(),
            name: "Test",
            selectedCategories: ["arms"],
            createdDate: .now,
            lastModified: .now
        )
        let exercise = Exercise(
            name: "Curl", weight: 20, reps: 10, sets: 3,
            iconName: "x", category: .arms
        )
        let model = ExerciseModel.from(exercise, sortOrder: 0, workout: workout)
        #expect(model.workoutId == workout.id)
    }

    @Test("V1 store with related rows migrates to V2 with backfilled workoutId")
    func endToEndMigrationBackfills() throws {
        let url = makeStoreURL()
        defer { cleanup(url) }

        let workoutId = UUID()
        let exerciseId = UUID()

        do {
            let v1 = try ModelContainer(
                for: SchemaV1.WorkoutModel.self,
                SchemaV1.ExerciseModel.self,
                SetProgressModel.self,
                AnalyticsEntryModel.self,
                ExerciseFeedbackModel.self,
                configurations: ModelConfiguration(url: url)
            )
            let ctx = ModelContext(v1)
            let workout = SchemaV1.WorkoutModel(
                id: workoutId,
                name: "Test",
                selectedCategories: ["arms"],
                createdDate: .now,
                lastModified: .now
            )
            let v1Exercise = SchemaV1.ExerciseModel(
                id: exerciseId,
                name: "Curl",
                weight: 20,
                reps: 10,
                sets: 3,
                iconName: "x",
                category: "arms",
                sortOrder: 0
            )
            v1Exercise.workout = workout
            ctx.insert(workout)
            ctx.insert(v1Exercise)
            try ctx.save()
        }

        let v2 = try ModelContainer(
            for: WorkoutModel.self,
            ExerciseModel.self,
            AnalyticsEntryModel.self,
            SetProgressModel.self,
            ExerciseFeedbackModel.self,
            migrationPlan: AppMigrationPlan.self,
            configurations: ModelConfiguration(url: url)
        )
        let ctx = ModelContext(v2)
        let fetched = try ctx.fetch(FetchDescriptor<ExerciseModel>(
            predicate: #Predicate<ExerciseModel> { $0.id == exerciseId }
        )).first
        let unwrapped = try #require(fetched)
        #expect(unwrapped.workoutId == workoutId)
        #expect(unwrapped.workout?.id == workoutId)
    }

    @Test("Re-opening a V2 store is idempotent — workoutId stays correct")
    func migrationIsIdempotent() throws {
        let url = makeStoreURL()
        defer { cleanup(url) }

        let workoutId = UUID()
        let exerciseId = UUID()

        do {
            let v1 = try ModelContainer(
                for: SchemaV1.WorkoutModel.self,
                SchemaV1.ExerciseModel.self,
                SetProgressModel.self,
                AnalyticsEntryModel.self,
                ExerciseFeedbackModel.self,
                configurations: ModelConfiguration(url: url)
            )
            let ctx = ModelContext(v1)
            let w = SchemaV1.WorkoutModel(
                id: workoutId, name: "T", selectedCategories: [],
                createdDate: .now, lastModified: .now
            )
            let e = SchemaV1.ExerciseModel(
                id: exerciseId, name: "X", weight: 0, reps: 1, sets: 1,
                iconName: "x", category: "arms"
            )
            e.workout = w
            ctx.insert(w); ctx.insert(e)
            try ctx.save()
        }

        // First V2 open — runs migration.
        _ = try ModelContainer(
            for: WorkoutModel.self,
            ExerciseModel.self,
            AnalyticsEntryModel.self,
            SetProgressModel.self,
            ExerciseFeedbackModel.self,
            migrationPlan: AppMigrationPlan.self,
            configurations: ModelConfiguration(url: url)
        )
        // Second V2 open — should not corrupt anything.
        let v2Again = try ModelContainer(
            for: WorkoutModel.self,
            ExerciseModel.self,
            AnalyticsEntryModel.self,
            SetProgressModel.self,
            ExerciseFeedbackModel.self,
            migrationPlan: AppMigrationPlan.self,
            configurations: ModelConfiguration(url: url)
        )
        let ctx = ModelContext(v2Again)
        let unwrapped = try #require(try ctx.fetch(FetchDescriptor<ExerciseModel>(
            predicate: #Predicate<ExerciseModel> { $0.id == exerciseId }
        )).first)
        #expect(unwrapped.workoutId == workoutId)
    }

    @Test("Orphan exercise (no workout relationship) survives migration without crashing")
    func orphanedExerciseSurvivesMigration() throws {
        let url = makeStoreURL()
        defer { cleanup(url) }

        let exerciseId = UUID()

        do {
            let v1 = try ModelContainer(
                for: SchemaV1.WorkoutModel.self,
                SchemaV1.ExerciseModel.self,
                SetProgressModel.self,
                AnalyticsEntryModel.self,
                ExerciseFeedbackModel.self,
                configurations: ModelConfiguration(url: url)
            )
            let ctx = ModelContext(v1)
            let orphan = SchemaV1.ExerciseModel(
                id: exerciseId, name: "Orphan", weight: 0, reps: 1, sets: 1,
                iconName: "x", category: "arms"
            )
            ctx.insert(orphan)
            try ctx.save()
        }

        let v2 = try ModelContainer(
            for: WorkoutModel.self,
            ExerciseModel.self,
            AnalyticsEntryModel.self,
            SetProgressModel.self,
            ExerciseFeedbackModel.self,
            migrationPlan: AppMigrationPlan.self,
            configurations: ModelConfiguration(url: url)
        )
        let ctx = ModelContext(v2)
        let fetched = try ctx.fetch(FetchDescriptor<ExerciseModel>(
            predicate: #Predicate<ExerciseModel> { $0.id == exerciseId }
        )).first
        let unwrapped = try #require(fetched)
        #expect(unwrapped.workout == nil)
        // Lightweight column-add inserts NULL for the optional new property,
        // and didMigrate skips orphans (no `workout?.id` to derive from). The
        // row survives in a sane state — production save paths will assign
        // a real workoutId on the next mutation.
        #expect(unwrapped.workoutId == nil)
    }
}
