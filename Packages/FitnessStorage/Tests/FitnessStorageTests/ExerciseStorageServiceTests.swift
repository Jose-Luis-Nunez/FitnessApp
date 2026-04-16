import Testing
import Foundation
import SwiftData
import FitnessCore
@testable import FitnessStorage
import Factory

@Suite("ExerciseStorageService", .serialized)
@MainActor
struct ExerciseStorageServiceTests {

    private let container: ModelContainer

    init() {
        container = TestHelpers.makeInMemoryContainer()
    }

    private func makeSUT() -> (ExerciseStorageService, Workout) {
        let ws = WorkoutStorageService(container: container)
        let workout = ws.workouts.first!
        let es = ExerciseStorageService(container: container)
        return (es, workout)
    }

    // MARK: - Save & Load Roundtrip

    @Test func saveAndLoadPreservesAllProperties() {
        let (sut, workout) = makeSUT()

        let exercise = TestHelpers.makeExercise(
            name: "Lat Pulldown",
            weight: 55,
            reps: 12,
            sets: 4,
            seatSetting: "5",
            category: .back,
            goal: 70
        )

        sut.saveForWorkout([exercise], workoutId: workout.id, category: .back)
        let loaded = sut.loadForWorkout(workoutId: workout.id, category: .back)

        #expect(loaded.count == 1)
        let result = loaded.first!
        #expect(result.name == "Lat Pulldown")
        #expect(result.weight == 55)
        #expect(result.reps == 12)
        #expect(result.sets == 4)
        #expect(result.seatSetting == "5")
        #expect(result.category == .back)
        #expect(result.goal == 70)
    }

    @Test func exerciseIdPreservedAcrossSave() {
        let (sut, workout) = makeSUT()
        let originalId = UUID()

        let exercise = Exercise(
            id: originalId,
            name: "Curl",
            weight: 20,
            reps: 10,
            sets: 3,
            iconName: "defaultArmsIcon",
            category: .arms
        )

        sut.saveForWorkout([exercise], workoutId: workout.id, category: .arms)
        let loaded = sut.loadForWorkout(workoutId: workout.id, category: .arms)

        #expect(loaded.first?.id == originalId)
    }

    @Test func completedFlagRoundtrip() {
        let (sut, workout) = makeSUT()

        let exercise = TestHelpers.makeExercise(name: "Completed", isCompleted: true, category: .chest)
        sut.saveForWorkout([exercise], workoutId: workout.id, category: .chest)

        let loaded = sut.loadForWorkout(workoutId: workout.id, category: .chest).first!
        #expect(loaded.isCompleted == true)
    }

    @Test func noSeatsFlagRoundtrip() {
        let (sut, workout) = makeSUT()

        let exercise = TestHelpers.makeExercise(name: "Planks", noSeats: true, category: .abs)
        sut.saveForWorkout([exercise], workoutId: workout.id, category: .abs)

        let loaded = sut.loadForWorkout(workoutId: workout.id, category: .abs).first!
        #expect(loaded.noSeats == true)
        #expect(loaded.seatSetting == nil)
    }

    @Test func nilGoalRoundtrip() {
        let (sut, workout) = makeSUT()

        let exercise = TestHelpers.makeExercise(name: "NoGoal", category: .legs)
        sut.saveForWorkout([exercise], workoutId: workout.id, category: .legs)

        let loaded = sut.loadForWorkout(workoutId: workout.id, category: .legs).first!
        #expect(loaded.goal == nil)
    }

    // MARK: - Ordering

    @Test func sortOrderPreservedForManyExercises() {
        let (sut, workout) = makeSUT()

        let names = (1...10).map { "Exercise \($0)" }
        let exercises = names.map { TestHelpers.makeExercise(name: $0, category: .arms) }

        sut.saveForWorkout(exercises, workoutId: workout.id, category: .arms)
        let loaded = sut.loadForWorkout(workoutId: workout.id, category: .arms)

        #expect(loaded.map(\.name) == names)
    }

    // MARK: - Category Isolation

    @Test func savingToCategoryDoesNotAffectOtherCategories() {
        let (sut, workout) = makeSUT()

        sut.saveForWorkout(
            [TestHelpers.makeExercise(name: "Arms1", category: .arms)],
            workoutId: workout.id,
            category: .arms
        )
        sut.saveForWorkout(
            [TestHelpers.makeExercise(name: "Chest1", category: .chest)],
            workoutId: workout.id,
            category: .chest
        )

        sut.saveForWorkout(
            [TestHelpers.makeExercise(name: "Arms2", category: .arms)],
            workoutId: workout.id,
            category: .arms
        )

        let arms = sut.loadForWorkout(workoutId: workout.id, category: .arms)
        let chest = sut.loadForWorkout(workoutId: workout.id, category: .chest)

        #expect(arms.count == 1)
        #expect(arms.first!.name == "Arms2")
        #expect(chest.count == 1)
        #expect(chest.first!.name == "Chest1")
    }

    @Test func allCategoriesWorkIndependently() {
        let (sut, workout) = makeSUT()

        for category in MuscleCategoryGroup.allCases {
            sut.saveForWorkout(
                [TestHelpers.makeExercise(name: "\(category.rawValue) exercise", category: category)],
                workoutId: workout.id,
                category: category
            )
        }

        for category in MuscleCategoryGroup.allCases {
            let loaded = sut.loadForWorkout(workoutId: workout.id, category: category)
            #expect(loaded.count == 1, "Category \(category.rawValue) should have 1 exercise")
        }
    }

    // MARK: - Workout Isolation

    @Test func exercisesIsolatedBetweenDifferentWorkouts() {
        let ws = WorkoutStorageService(container: container)
        let workout1 = ws.workouts.first!
        let workout2 = ws.createWorkout(name: "Second")
        let sut = ExerciseStorageService(container: container)

        sut.saveForWorkout(
            [TestHelpers.makeExercise(name: "W1 Curl", category: .arms)],
            workoutId: workout1.id,
            category: .arms
        )
        sut.saveForWorkout(
            [TestHelpers.makeExercise(name: "W2 Curl", category: .arms)],
            workoutId: workout2.id,
            category: .arms
        )

        let w1Loaded = sut.loadForWorkout(workoutId: workout1.id, category: .arms)
        let w2Loaded = sut.loadForWorkout(workoutId: workout2.id, category: .arms)

        #expect(w1Loaded.count == 1)
        #expect(w1Loaded.first!.name == "W1 Curl")
        #expect(w2Loaded.count == 1)
        #expect(w2Loaded.first!.name == "W2 Curl")
    }

    // MARK: - Overwrite Behavior

    @Test func saveOverwritesAllPreviousExercisesInCategory() {
        let (sut, workout) = makeSUT()

        sut.saveForWorkout(
            [
                TestHelpers.makeExercise(name: "Old1", category: .chest),
                TestHelpers.makeExercise(name: "Old2", category: .chest),
                TestHelpers.makeExercise(name: "Old3", category: .chest)
            ],
            workoutId: workout.id,
            category: .chest
        )

        sut.saveForWorkout(
            [TestHelpers.makeExercise(name: "New1", category: .chest)],
            workoutId: workout.id,
            category: .chest
        )

        let loaded = sut.loadForWorkout(workoutId: workout.id, category: .chest)
        #expect(loaded.count == 1)
        #expect(loaded.first!.name == "New1")
    }

    @Test func saveEmptyArrayClearsCategory() {
        let (sut, workout) = makeSUT()

        sut.saveForWorkout(
            [TestHelpers.makeExercise(name: "To Remove", category: .legs)],
            workoutId: workout.id,
            category: .legs
        )
        #expect(sut.loadForWorkout(workoutId: workout.id, category: .legs).count == 1)

        sut.saveForWorkout([], workoutId: workout.id, category: .legs)
        #expect(sut.loadForWorkout(workoutId: workout.id, category: .legs).count == 0)
    }

    // MARK: - Empty State

    @Test func loadFromNonExistentWorkoutReturnsEmpty() {
        let (sut, _) = makeSUT()
        let loaded = sut.loadForWorkout(workoutId: UUID(), category: .arms)
        #expect(loaded.isEmpty)
    }

    @Test func loadFromEmptyCategoryReturnsEmpty() {
        let (sut, workout) = makeSUT()
        let loaded = sut.loadForWorkout(workoutId: workout.id, category: .legs)
        #expect(loaded.isEmpty)
    }

    // MARK: - Persistence Across Service Instances

    @Test func dataPersistedAcrossServiceInstances() {
        let ws = WorkoutStorageService(container: container)
        let workout = ws.workouts.first!

        let sut1 = ExerciseStorageService(container: container)
        sut1.saveForWorkout(
            [TestHelpers.makeExercise(name: "Persistent", category: .chest)],
            workoutId: workout.id,
            category: .chest
        )

        let sut2 = ExerciseStorageService(container: container)
        let loaded = sut2.loadForWorkout(workoutId: workout.id, category: .chest)
        #expect(loaded.count == 1)
        #expect(loaded.first!.name == "Persistent")
    }

    // MARK: - Icon Name

    @Test func customIconNamePreserved() {
        let (sut, workout) = makeSUT()

        let exercise = TestHelpers.makeExercise(name: "Custom Icon", category: .arms, iconName: "bicepsIcon")
        sut.saveForWorkout([exercise], workoutId: workout.id, category: .arms)

        let loaded = sut.loadForWorkout(workoutId: workout.id, category: .arms).first!
        #expect(loaded.iconName == "bicepsIcon")
    }

    @Test func defaultIconNameUsedWhenNoneSpecified() {
        let (sut, workout) = makeSUT()

        let exercise = TestHelpers.makeExercise(name: "Default Icon", category: .chest)
        sut.saveForWorkout([exercise], workoutId: workout.id, category: .chest)

        let loaded = sut.loadForWorkout(workoutId: workout.id, category: .chest).first!
        #expect(loaded.iconName == "defaultChestIcon")
    }
}
