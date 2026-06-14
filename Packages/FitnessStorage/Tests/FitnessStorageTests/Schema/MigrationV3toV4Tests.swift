import Foundation
import SwiftData
import Testing
import FitnessCore
import FitnessTestSupport
@_spi(PersistenceUI) @testable import FitnessStorage

/// Tests for the SchemaV3 → SchemaV4 migration (ADR-0005) that adds the optional
/// `ExerciseModel.isActive: Bool?` (deactivate/reactivate feature).
///
/// V3→V4 is a `lightweight` stage, so ADR-0005 does not strictly require a test.
/// We add one anyway because the whole feature leans on one contract: a row that
/// predates V4 has `isActive == nil` and must read back as **active**
/// (`isActive ?? true == true`). This pins that contract at the real
/// container-version transition.
@MainActor
@Suite("V3 → V4 migration adds isActive; legacy rows read as active", .serialized, .tags(.integration))
struct MigrationV3toV4Tests {

    private func makeStoreURL() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "MigrationV3toV4-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "default.store")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    /// Writes a store stamped as `SchemaV3` using the `SchemaV2` snapshot classes
    /// (V3 reuses them for the `ExerciseModel`/`WorkoutModel` cluster — there is
    /// no `isActive` column yet). Opening with the bare versioned schema and no
    /// plan stamps the store with `(3,0,0)`.
    private func writeV3Store(at url: URL, workoutId: UUID, exerciseId: UUID) throws {
        let v3 = try ModelContainer(
            for: Schema(versionedSchema: SchemaV3.self),
            configurations: ModelConfiguration(url: url)
        )
        let ctx = ModelContext(v3)
        let workout = SchemaV2.WorkoutModel(
            id: workoutId,
            name: "Legs",
            selectedCategories: ["legs"],
            createdDate: .now,
            lastModified: .now,
            isDefault: true
        )
        ctx.insert(workout)
        let exercise = SchemaV2.ExerciseModel(
            id: exerciseId,
            workoutId: workoutId,
            name: "Squat",
            weight: 100,
            reps: 5,
            sets: 5,
            iconName: "x",
            category: "legs",
            sortOrder: 0,
            workout: workout
        )
        ctx.insert(exercise)
        try ctx.save()
    }

    private func openV4(at url: URL) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: SchemaV4.self),
            migrationPlan: AppMigrationPlan.self,
            configurations: ModelConfiguration(url: url)
        )
    }

    @Test("Legacy V3 row migrates to V4 with isActive == nil, read as active")
    func legacyRowReadsAsActive() throws {
        let url = makeStoreURL()
        defer { cleanup(url) }

        let workoutId = UUID()
        let exerciseId = UUID()
        try writeV3Store(at: url, workoutId: workoutId, exerciseId: exerciseId)

        let v4 = try openV4(at: url)
        let ctx = ModelContext(v4)

        let exercise = try #require(try ctx.fetch(FetchDescriptor<ExerciseModel>(
            predicate: #Predicate { $0.id == exerciseId }
        )).first)

        // Lightweight column-add leaves the optional NULL for existing rows…
        #expect(exercise.isActive == nil)
        // …and every read path interprets that as active.
        #expect(exercise.toDomain().isActive == true)
        // Other data survives the migration.
        #expect(exercise.name == "Squat")
        #expect(exercise.workoutId == workoutId)
    }

    @Test("isActive round-trips through a V4 store after migration")
    func isActiveRoundTrips() throws {
        let url = makeStoreURL()
        defer { cleanup(url) }

        let exerciseId = UUID()
        try writeV3Store(at: url, workoutId: UUID(), exerciseId: exerciseId)

        let v4 = try openV4(at: url)
        let ctx = ModelContext(v4)
        let exercise = try #require(try ctx.fetch(FetchDescriptor<ExerciseModel>(
            predicate: #Predicate { $0.id == exerciseId }
        )).first)

        exercise.isActive = false
        try ctx.save()

        let reopened = ModelContext(try openV4(at: url))
        let again = try #require(try reopened.fetch(FetchDescriptor<ExerciseModel>(
            predicate: #Predicate { $0.id == exerciseId }
        )).first)
        #expect(again.isActive == false)
        #expect(again.toDomain().isActive == false)
    }
}
