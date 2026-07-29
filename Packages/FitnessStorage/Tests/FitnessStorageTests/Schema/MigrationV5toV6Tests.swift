import Foundation
import FitnessCore
import SwiftData
import Testing
@_spi(PersistenceUI) @testable import FitnessStorage

@MainActor
@Suite("V5 → V6 migration adds workout exercise order", .serialized, .tags(.integration))
struct MigrationV5toV6Tests {
    @Test("Existing workout and exercise survive and the order table is usable")
    func migratesExistingDataAndCreatesOrderTable() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "MigrationV5toV6-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "default.store")
        let workoutId = UUID()
        let exerciseId = UUID()
        let analyticsId = UUID()

        do {
            let v5 = try ModelContainer(
                for: Schema(versionedSchema: SchemaV5.self),
                configurations: ModelConfiguration(url: url)
            )
            let context = ModelContext(v5)
            let workout = WorkoutModel(
                id: workoutId,
                name: "Legacy V5 Workout",
                selectedCategories: ["arms"],
                createdDate: .now,
                lastModified: .now,
                typeRaw: WorkoutType.pull.rawValue
            )
            context.insert(workout)
            context.insert(ExerciseModel(
                id: exerciseId,
                workoutId: workoutId,
                name: "Legacy Curl",
                weight: 20,
                reps: 10,
                sets: 3,
                iconName: "defaultArmsIcon",
                category: "arms",
                workout: workout
            ))
            let analytics = AnalyticsEntryModel(
                id: analyticsId,
                exerciseId: exerciseId,
                date: Date(timeIntervalSince1970: 1_700_000_000)
            )
            analytics.setProgressEntries = [
                SetProgressModel(
                    status: SetStatus.completedDone.rawValue,
                    currentReps: 12,
                    weight: 22.5,
                    sortOrder: 0,
                    entry: analytics
                )
            ]
            context.insert(analytics)
            try context.save()
        }

        let v6 = try ModelContainer(
            for: Schema(versionedSchema: SchemaV6.self),
            migrationPlan: AppMigrationPlan.self,
            configurations: ModelConfiguration(url: url)
        )
        let context = ModelContext(v6)
        let workouts = try context.fetch(FetchDescriptor<WorkoutModel>())
        let exercises = try context.fetch(FetchDescriptor<ExerciseModel>())
        let analytics = try context.fetch(FetchDescriptor<AnalyticsEntryModel>())
        #expect(workouts.map(\.id) == [workoutId])
        #expect(exercises.map(\.id) == [exerciseId])
        let migratedAnalytics = try #require(analytics.first)
        #expect(migratedAnalytics.id == analyticsId)
        #expect(migratedAnalytics.exerciseId == exerciseId)
        let migratedSet = try #require(migratedAnalytics.setProgressEntries.first)
        #expect(migratedSet.status == SetStatus.completedDone.rawValue)
        #expect(migratedSet.currentReps == 12)
        #expect(migratedSet.weight == 22.5)
        #expect(try context.fetch(FetchDescriptor<WorkoutExerciseOrderModel>()).isEmpty)

        context.insert(WorkoutExerciseOrderModel(
            workoutId: workoutId,
            learnedExerciseIds: [exerciseId]
        ))
        try context.save()
        let order = try #require(
            try context.fetch(FetchDescriptor<WorkoutExerciseOrderModel>()).first
        )
        #expect(order.learnedExerciseIds == [exerciseId])
    }
}
