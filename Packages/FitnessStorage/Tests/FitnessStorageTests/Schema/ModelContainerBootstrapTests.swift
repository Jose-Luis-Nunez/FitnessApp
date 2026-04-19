import Foundation
import SwiftData
import Testing
import FitnessCore
@_spi(PersistenceUI) @testable import FitnessStorage

/// Tests for `ModelContainerBootstrap`, the production fallback chain that
/// turns the pre-T3 → T3 migration crash on real devices into a transparent
/// upgrade.
///
/// Why these tests exist: pre-T3 builds opened the store as
/// `ModelContainer(for: WorkoutModel.self, …)` with no `VersionedSchema`. Once
/// T3 introduced `AppMigrationPlan`, opening such a store with the plan throws
/// `SwiftDataError.loadIssueModelContainer` because there is no
/// `(legacy → V1)` stage. The bootstrap recovers by adopting the on-disk store
/// as `SchemaV1` first (which physically matches the pre-T3 shape and stamps
/// it with `(1,0,0)`), then re-opens with the plan so the existing
/// `migrateV1toV2_addWorkoutId` runs and user data survives.
///
/// We can't call the real `ModelContainerBootstrap.makeProductionContainer()`
/// in tests because it pins the store to `Application Support/default.store`,
/// which would clobber the dev simulator's app data. Instead we mirror its
/// internal three-step strategy against per-test scratch URLs so the same
/// algorithm is exercised end-to-end, against a real on-disk SQLite store,
/// with the same `AppMigrationPlan`.
@MainActor
@Suite("ModelContainerBootstrap recovers pre-versioned stores", .serialized)
struct ModelContainerBootstrapTests {

    private func makeStoreURL() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "BootstrapRecovery-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "store.sqlite")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    /// Reproduces a pre-T3 store: opens a SwiftData container with the live
    /// classes **without** declaring `Schema(versionedSchema:)`. SwiftData
    /// stamps the store with an implicit identity that is not `(1,0,0)`. This
    /// is the exact shape on the user's phone in the original bug report.
    private func writeLegacyPreVersionedStore(at url: URL, workoutId: UUID, exerciseId: UUID) throws {
        let legacy = try ModelContainer(
            for: SchemaV1.WorkoutModel.self,
            SchemaV1.ExerciseModel.self,
            SetProgressModel.self,
            AnalyticsEntryModel.self,
            ExerciseFeedbackModel.self,
            configurations: ModelConfiguration(url: url)
        )
        let ctx = ModelContext(legacy)
        let workout = SchemaV1.WorkoutModel(
            id: workoutId, name: "Pre-T3", selectedCategories: ["arms"],
            createdDate: .now, lastModified: .now
        )
        let exercise = SchemaV1.ExerciseModel(
            id: exerciseId, name: "Curl", weight: 20, reps: 10, sets: 3,
            iconName: "x", category: "arms"
        )
        exercise.workout = workout
        ctx.insert(workout)
        ctx.insert(exercise)
        try ctx.save()
    }

    /// The strategy under test, expressed against an injectable URL so the
    /// production code (which pins to Application Support) and the test code
    /// stay in lockstep without test pollution leaking into the dev sim.
    private func bootstrapRecover(at url: URL) throws -> ModelContainer {
        let v2Schema = Schema(versionedSchema: SchemaV2.self)
        let configuration = ModelConfiguration(url: url)

        if let direct = try? ModelContainer(
            for: v2Schema, migrationPlan: AppMigrationPlan.self, configurations: configuration
        ) {
            return direct
        }

        let v1Schema = Schema(versionedSchema: SchemaV1.self)
        _ = try ModelContainer(for: v1Schema, configurations: configuration)

        return try ModelContainer(
            for: v2Schema, migrationPlan: AppMigrationPlan.self, configurations: configuration
        )
    }

    @Test("Fresh install: V2 container opens directly, no recovery needed")
    func freshInstallTakesPrimaryPath() throws {
        let url = makeStoreURL()
        defer { cleanup(url) }

        let container = try bootstrapRecover(at: url)
        let ctx = ModelContext(container)
        let count = try ctx.fetchCount(FetchDescriptor<ExerciseModel>())
        #expect(count == 0)
    }

    @Test("Pre-T3 store: V1 adoption unblocks the V2 plan and preserves data")
    func preT3StoreRecoversAndMigrates() throws {
        let url = makeStoreURL()
        defer { cleanup(url) }

        let workoutId = UUID()
        let exerciseId = UUID()
        try writeLegacyPreVersionedStore(at: url, workoutId: workoutId, exerciseId: exerciseId)

        let container = try bootstrapRecover(at: url)
        let ctx = ModelContext(container)
        let fetched = try #require(try ctx.fetch(FetchDescriptor<ExerciseModel>(
            predicate: #Predicate<ExerciseModel> { $0.id == exerciseId }
        )).first)

        #expect(fetched.workoutId == workoutId, "Migration must backfill workoutId from carried-over relationship")
        #expect(fetched.workout?.id == workoutId, "Relationship must survive the legacy → V1 → V2 pipeline")
    }

    @Test("Recovered V2 store re-opens directly on subsequent launches")
    func recoveredStoreOpensDirectlyNextTime() throws {
        let url = makeStoreURL()
        defer { cleanup(url) }

        try writeLegacyPreVersionedStore(at: url, workoutId: UUID(), exerciseId: UUID())
        _ = try bootstrapRecover(at: url)

        let v2Schema = Schema(versionedSchema: SchemaV2.self)
        let secondOpen = try ModelContainer(
            for: v2Schema, migrationPlan: AppMigrationPlan.self,
            configurations: ModelConfiguration(url: url)
        )
        let ctx = ModelContext(secondOpen)
        #expect(try ctx.fetchCount(FetchDescriptor<ExerciseModel>()) == 1)
    }
}
