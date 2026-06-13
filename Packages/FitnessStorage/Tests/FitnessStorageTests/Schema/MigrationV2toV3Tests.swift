import Foundation
import SwiftData
import Testing
import FitnessCore
import FitnessTestSupport
@_spi(PersistenceUI) @testable import FitnessStorage

/// Tests for the SchemaV2 → SchemaV3 migration (ADR-0005) that adds
/// `FriendModel` for the Friends comparison feature.
///
/// V2→V3 is declared as a `lightweight` stage (additive only — a brand-new
/// model, no changes to existing entities). ADR-0005 § Test-Pflicht does not
/// strictly require a test for lightweight stages, but the real-device failure
/// the Friends release surfaced was in the **container open**, not the stage
/// logic: a V2 store that throws on `open(plan + V3)` is quarantined and its
/// data vanishes from the UI. So we exercise the **real container-version
/// transition** — write rows in genuine V2 form, then re-open the same store
/// with `AppMigrationPlan` targeting V3 — to guarantee existing workouts and
/// exercises survive and the new `FriendModel` table is usable afterwards.
@MainActor
@Suite("V2 → V3 migration adds FriendModel and preserves workout data", .serialized, .tags(.integration))
struct MigrationV2toV3Tests {

    /// Per-test scratch directory so each test gets its own SQLite store; the
    /// migration runs once per container-open, so we MUST start clean.
    private func makeStoreURL() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "MigrationV2toV3-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "default.store")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    /// Writes a store stamped as `SchemaV2` (the youngest schema that still
    /// references the live `WorkoutModel`/`ExerciseModel` classes, so the live
    /// types match the V2 on-disk shape). Opening with the bare versioned
    /// schema and **no** plan stamps the store with `(2,0,0)`.
    private func writeV2Store(at url: URL, workoutId: UUID, exerciseId: UUID) throws {
        let v2 = try ModelContainer(
            for: Schema(versionedSchema: SchemaV2.self),
            configurations: ModelConfiguration(url: url)
        )
        let ctx = ModelContext(v2)
        let workout = WorkoutModel(
            id: workoutId,
            name: "Legs",
            selectedCategories: ["legs"],
            createdDate: .now,
            lastModified: .now,
            isDefault: true
        )
        ctx.insert(workout)
        let exercise = ExerciseModel.from(
            Exercise(id: exerciseId, name: "Squat", weight: 100, reps: 5, sets: 5, iconName: "x", category: .legs),
            sortOrder: 0,
            workout: workout
        )
        ctx.insert(exercise)
        try ctx.save()
    }

    private func openV3(at url: URL) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: SchemaV3.self),
            migrationPlan: AppMigrationPlan.self,
            configurations: ModelConfiguration(url: url)
        )
    }

    @Test("V2 store opens as V3 with workouts and exercises intact")
    func v2StoreMigratesPreservingData() throws {
        let url = makeStoreURL()
        defer { cleanup(url) }

        let workoutId = UUID()
        let exerciseId = UUID()
        try writeV2Store(at: url, workoutId: workoutId, exerciseId: exerciseId)

        let v3 = try openV3(at: url)
        let ctx = ModelContext(v3)

        let workout = try #require(try ctx.fetch(FetchDescriptor<WorkoutModel>(
            predicate: #Predicate { $0.id == workoutId }
        )).first)
        #expect(workout.name == "Legs")

        let exercise = try #require(try ctx.fetch(FetchDescriptor<ExerciseModel>(
            predicate: #Predicate { $0.id == exerciseId }
        )).first)
        #expect(exercise.workoutId == workoutId, "workoutId carried over from V2 must survive")
        #expect(exercise.workout?.id == workoutId)
    }

    @Test("FriendModel table is empty after migration and accepts inserts")
    func friendModelUsableAfterMigration() throws {
        let url = makeStoreURL()
        defer { cleanup(url) }

        try writeV2Store(at: url, workoutId: UUID(), exerciseId: UUID())

        let v3 = try openV3(at: url)
        let ctx = ModelContext(v3)

        #expect(try ctx.fetchCount(FetchDescriptor<FriendModel>()) == 0, "new table starts empty")

        let friendId = UUID()
        ctx.insert(FriendModel(
            id: friendId,
            name: "Lisa",
            addedAt: .now,
            envelopeJSON: "{}",
            workoutName: "Legs"
        ))
        try ctx.save()

        let friend = try #require(try ctx.fetch(FetchDescriptor<FriendModel>(
            predicate: #Predicate { $0.id == friendId }
        )).first)
        #expect(friend.name == "Lisa")
    }

    @Test("Re-opening a migrated V3 store is idempotent and keeps data")
    func reopenV3IsIdempotent() throws {
        let url = makeStoreURL()
        defer { cleanup(url) }

        let workoutId = UUID()
        try writeV2Store(at: url, workoutId: workoutId, exerciseId: UUID())

        _ = try openV3(at: url)        // first open runs V2→V3
        let v3Again = try openV3(at: url) // second open must not corrupt anything
        let ctx = ModelContext(v3Again)

        #expect(try ctx.fetchCount(FetchDescriptor<WorkoutModel>()) == 1)
        let workout = try #require(try ctx.fetch(FetchDescriptor<WorkoutModel>(
            predicate: #Predicate { $0.id == workoutId }
        )).first)
        #expect(workout.name == "Legs")
    }
}
