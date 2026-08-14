import Foundation
import FitnessTestSupport
import SwiftData
import Testing
import FitnessCore
@_spi(PersistenceUI) import FitnessStorage
@testable import FitnessPersistenceUI

@MainActor
@Suite("CategoryTileModelView production contracts", .tags(.integration))
struct CategoryTileModelViewTests {

    @Test("Production predicate isolates workout and category")
    func predicateIsolatesWorkoutAndCategory() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let selectedWorkout = makeWorkout(name: "Selected")
        let otherWorkout = makeWorkout(name: "Other")
        context.insert(selectedWorkout)
        context.insert(otherWorkout)

        let matching = makeExercise(workout: selectedWorkout, category: .arms)
        context.insert(matching)
        context.insert(makeExercise(workout: selectedWorkout, category: .chest))
        context.insert(makeExercise(workout: otherWorkout, category: .arms))
        try context.save()

        let descriptor = FetchDescriptor<ExerciseModel>(
            predicate: CategoryTileExerciseQuery.predicate(
                workoutId: selectedWorkout.id,
                category: .arms
            )
        )

        #expect(try context.fetch(descriptor).map(\.id) == [matching.id])
    }

    @Test("Production aggregation handles completion, deactivation, legacy rows and active sessions")
    func progressAggregationCoversMeaningfulStates() {
        let workout = makeWorkout(name: "Workout")
        let open = makeExercise(workout: workout, category: .arms)
        open.isActive = nil
        let completed = makeExercise(workout: workout, category: .arms)
        completed.isCompleted = true
        completed.isActive = true
        let deactivated = makeExercise(workout: workout, category: .arms)
        deactivated.isActive = false

        let partial = CategoryTileProgressInfo(
            exercises: [open, completed, deactivated],
            hasActiveSet: false
        )
        #expect(partial.total == 2)
        #expect(partial.completed == 1)
        #expect(partial.progress == 0.5)
        #expect(!partial.isCompleted)

        open.isCompleted = true
        let completedWithoutSession = CategoryTileProgressInfo(
            exercises: [open, completed, deactivated],
            hasActiveSet: false
        )
        #expect(completedWithoutSession.isCompleted)

        let completedWithSession = CategoryTileProgressInfo(
            exercises: [open, completed, deactivated],
            hasActiveSet: true
        )
        #expect(!completedWithSession.isCompleted)

        let empty = CategoryTileProgressInfo(exercises: [], hasActiveSet: false)
        #expect(empty.total == 0)
        #expect(empty.completed == 0)
        #expect(empty.progress == 0)
        #expect(!empty.isCompleted)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: WorkoutModel.self,
            ExerciseModel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeWorkout(name: String) -> WorkoutModel {
        WorkoutModel(
            id: UUID(),
            name: name,
            selectedCategories: [MuscleCategoryGroup.arms.rawValue],
            createdDate: .now,
            lastModified: .now
        )
    }

    private func makeExercise(
        workout: WorkoutModel,
        category: MuscleCategoryGroup
    ) -> ExerciseModel {
        ExerciseModel(
            id: UUID(),
            workoutId: workout.id,
            name: "Exercise",
            weight: 20,
            reps: 10,
            sets: 3,
            iconName: category.defaultIconName,
            category: category.rawValue,
            workout: workout
        )
    }
}
