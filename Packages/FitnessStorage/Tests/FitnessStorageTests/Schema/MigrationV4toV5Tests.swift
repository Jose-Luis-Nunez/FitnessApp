import Foundation
import SwiftData
import Testing
import FitnessCore
@_spi(PersistenceUI) @testable import FitnessStorage

@MainActor
@Suite("V4 → V5 migration adds workout type", .serialized, .tags(.integration))
struct MigrationV4toV5Tests {
    private func makeStoreURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "MigrationV4toV5-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "default.store")
    }

    private func cleanup(_ url: URL) {
        // Best-effort cleanup must not mask the migration assertion result.
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    private func writeV4Store(at url: URL, workoutId: UUID, exerciseId: UUID) throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: SchemaV4.self),
            configurations: ModelConfiguration(url: url)
        )
        let context = ModelContext(container)
        let workout = SchemaV4.WorkoutModel(
            id: workoutId,
            name: "Legacy Workout",
            selectedCategories: ["legs"],
            createdDate: .now,
            lastModified: .now,
            isDefault: true
        )
        context.insert(workout)
        context.insert(SchemaV4.ExerciseModel(
            id: exerciseId,
            workoutId: workoutId,
            name: "Legacy Squat",
            weight: 120,
            reps: 5,
            sets: 4,
            isCompleted: true,
            iconName: "defaultLegsIcon",
            category: "legs",
            sortOrder: 2,
            isActive: false,
            workout: workout
        ))
        try context.save()
    }

    private func openV5(at url: URL) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: SchemaV5.self),
            migrationPlan: AppMigrationPlan.self,
            configurations: ModelConfiguration(url: url)
        )
    }

    @Test("Legacy workout defaults to Individual after migration")
    func legacyWorkoutDefaultsToIndividual() throws {
        let url = try makeStoreURL()
        defer { cleanup(url) }
        let workoutId = UUID()
        let exerciseId = UUID()
        try writeV4Store(at: url, workoutId: workoutId, exerciseId: exerciseId)

        let container = try openV5(at: url)
        let context = ModelContext(container)
        let workout = try #require(try context.fetch(FetchDescriptor<WorkoutModel>(
            predicate: #Predicate<WorkoutModel> { $0.id == workoutId }
        )).first)

        #expect(workout.typeRaw == nil)
        #expect(workout.toDomain().type == .individual)
        #expect(workout.name == "Legacy Workout")
        #expect(workout.selectedCategories == ["legs"])
        #expect(workout.isDefault)

        let exercise = try #require(try context.fetch(FetchDescriptor<ExerciseModel>(
            predicate: #Predicate<ExerciseModel> { $0.id == exerciseId }
        )).first)
        #expect(exercise.workoutId == workoutId)
        #expect(exercise.workout?.id == workoutId)
        #expect(exercise.name == "Legacy Squat")
        #expect(exercise.isActive == false)
        #expect(exercise.isCompleted)
    }

    @Test("Workout type round-trips in a V5 store")
    func workoutTypeRoundTrips() throws {
        let url = try makeStoreURL()
        defer { cleanup(url) }
        let workoutId = UUID()
        try writeV4Store(at: url, workoutId: workoutId, exerciseId: UUID())

        let firstContainer = try openV5(at: url)
        let firstContext = ModelContext(firstContainer)
        let workout = try #require(try firstContext.fetch(FetchDescriptor<WorkoutModel>(
            predicate: #Predicate<WorkoutModel> { $0.id == workoutId }
        )).first)
        workout.typeRaw = WorkoutType.leg.rawValue
        try firstContext.save()

        let secondContainer = try openV5(at: url)
        let secondContext = ModelContext(secondContainer)
        let reloaded = try #require(try secondContext.fetch(FetchDescriptor<WorkoutModel>(
            predicate: #Predicate<WorkoutModel> { $0.id == workoutId }
        )).first)
        #expect(reloaded.toDomain().type == .leg)
    }
}
