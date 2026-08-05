import Testing
import Foundation
import SwiftData
import FitnessCore
import FitnessTestSupport
@_spi(PersistenceUI) @testable import FitnessStorage
@Suite("ExerciseStorageService", .tags(.integration))
@MainActor
struct ExerciseStorageServiceTests {

    private let container: ModelContainer

    init() {
        container = TestHelpers.makeInMemoryContainer()
    }

    private func makeSUT() -> (ExerciseStorageService, Workout) {
        let ws = TestHelpers.makeWorkoutStorageService(container: container)
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

    // MARK: - Shared main-context coherence (Option B contract)

    /// A service write must be visible via the container's `mainContext` — the
    /// context the views' `@Query<ExerciseModel>` observe.
    @Test func writeIsVisibleOnSharedMainContext() throws {
        let (sut, workout) = makeSUT()
        let exercise = TestHelpers.makeExercise(name: "Shared", category: .arms)
        sut.saveForWorkout([exercise], workoutId: workout.id, category: .arms)

        let id = exercise.id
        let descriptor = FetchDescriptor<ExerciseModel>(predicate: #Predicate { $0.id == id })
        let onMainContext = try container.mainContext.fetch(descriptor)

        #expect(onMainContext.count == 1)
        #expect(onMainContext.first?.name == "Shared")
        // SUT reads back from the same shared context it wrote to (closes the loop).
        #expect(sut.loadForWorkout(workoutId: workout.id, category: .arms).count == 1)
    }

    /// A targeted update must be reflected on the `mainContext` **in place** — the
    /// same row object mutates (no delete+reinsert), so a `@Query` never strands a
    /// deleted object as a phantom card. This is the crux of unifying onto one
    /// context (Option B) combined with the targeted update (ADR-0009).
    @Test func updateIsReflectedInPlaceOnSharedMainContext() throws {
        let (sut, workout) = makeSUT()
        let e = TestHelpers.makeExercise(name: "A", seatSetting: "1", category: .arms)
        sut.saveForWorkout([e], workoutId: workout.id, category: .arms)

        let id = e.id
        let descriptor = FetchDescriptor<ExerciseModel>(predicate: #Predicate { $0.id == id })
        let before = try container.mainContext.fetch(descriptor).first
        #expect(before?.seatSetting == "1")

        var updated = e
        updated.seatSetting = "22 / 2"
        sut.updateExercise(updated)

        let after = try container.mainContext.fetch(descriptor)
        #expect(after.count == 1)
        #expect(after.first?.seatSetting == "22 / 2")
        #expect(after.first === before) // same row instance — in-place, identity preserved
    }

    // MARK: - Targeted Update (in-place, non-destructive)

    @Test func updateExerciseMutatesInPlacePreservingOthers() {
        let (sut, workout) = makeSUT()
        let e1 = TestHelpers.makeExercise(name: "A", weight: 10, seatSetting: "1", category: .arms)
        let e2 = TestHelpers.makeExercise(name: "B", weight: 20, category: .arms)
        sut.saveForWorkout([e1, e2], workoutId: workout.id, category: .arms)

        var updated = e1
        updated.seatSetting = "22 / 2"
        updated.weight = 99
        sut.updateExercise(updated)

        let loaded = sut.loadForWorkout(workoutId: workout.id, category: .arms)
        #expect(loaded.count == 2) // no duplicate, no deletion
        let reloaded1 = loaded.first { $0.id == e1.id }
        #expect(reloaded1?.seatSetting == "22 / 2")
        #expect(reloaded1?.weight == 99)
        let reloaded2 = loaded.first { $0.id == e2.id }
        #expect(reloaded2?.name == "B")
        #expect(reloaded2?.weight == 20)
    }

    @Test func updateExercisePreservesSortOrder() {
        let (sut, workout) = makeSUT()
        let exercises = (0..<3).map { TestHelpers.makeExercise(name: "E\($0)", category: .arms) }
        sut.saveForWorkout(exercises, workoutId: workout.id, category: .arms)

        var middle = exercises[1]
        middle.seatSetting = "9"
        sut.updateExercise(middle)

        let loaded = sut.loadForWorkout(workoutId: workout.id, category: .arms)
        #expect(loaded.map(\.id) == exercises.map(\.id)) // order unchanged
        #expect(loaded[1].seatSetting == "9")
    }

    @Test func deactivateRemovesExerciseFromLearnedOrderBeforeReactivation() throws {
        let (sut, workout) = makeSUT()
        let first = TestHelpers.makeExercise(name: "A", category: .arms)
        let second = TestHelpers.makeExercise(name: "B", category: .arms)
        sut.saveForWorkout([first, second], workoutId: workout.id, category: .arms)

        let order = WorkoutExerciseOrderModel(
            workoutId: workout.id,
            pendingExerciseIds: [first.id],
            candidateExerciseIds: [second.id, first.id],
            candidateRepeatCount: 1,
            learnedExerciseIds: [second.id, first.id]
        )
        container.mainContext.insert(order)
        try container.mainContext.save()

        var deactivated = first
        deactivated.isActive = false
        sut.updateExercise(deactivated)

        #expect(order.pendingExerciseIds.isEmpty)
        #expect(order.candidateExerciseIds.isEmpty)
        #expect(order.candidateRepeatCount == 0)
        #expect(order.learnedExerciseIds == [second.id])

        var reactivated = deactivated
        reactivated.isActive = true
        sut.updateExercise(reactivated)

        #expect(order.learnedExerciseIds == [second.id])
    }

    @Test func updateExerciseIsNoOpForUnknownId() {
        let (sut, workout) = makeSUT()
        let e1 = TestHelpers.makeExercise(name: "A", category: .arms)
        sut.saveForWorkout([e1], workoutId: workout.id, category: .arms)

        let stranger = TestHelpers.makeExercise(name: "X", category: .arms) // different id
        sut.updateExercise(stranger)

        let loaded = sut.loadForWorkout(workoutId: workout.id, category: .arms)
        #expect(loaded.count == 1)
        #expect(loaded.first?.name == "A")
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

    @Test func exercisesIsolatedBetweenDifferentWorkouts() throws {
        let ws = TestHelpers.makeWorkoutStorageService(container: container)
        let workout1 = ws.workouts.first!
        let workout2 = try ws.createWorkout(name: "Second")
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

    @Test func workoutWideLoadIsIsolatedAndPreservesCategorySortOrder() throws {
        let ws = TestHelpers.makeWorkoutStorageService(container: container)
        let workout1 = ws.workouts.first!
        let workout2 = try ws.createWorkout(name: "Second")
        let sut = ExerciseStorageService(container: container)
        for category in MuscleCategoryGroup.allCases.reversed() {
            sut.saveForWorkout(
                [
                    TestHelpers.makeExercise(name: "\(category.rawValue)-1", category: category),
                    TestHelpers.makeExercise(name: "\(category.rawValue)-2", category: category),
                ],
                workoutId: workout1.id,
                category: category
            )
        }
        sut.saveForWorkout(
            [TestHelpers.makeExercise(name: "Foreign", category: .arms)],
            workoutId: workout2.id,
            category: .arms
        )

        let loaded = try sut.loadWorkoutExercises(for: workout1.id)
        let expectedNames = MuscleCategoryGroup.allCases.flatMap { category in
            ["\(category.rawValue)-1", "\(category.rawValue)-2"]
        }

        #expect(loaded.map(\.name) == expectedNames)
        #expect(loaded.allSatisfy { $0.name != "Foreign" })
    }

    @Test func mockWorkoutScopedFixtureTracksUpdatesAndReseeding() throws {
        let workoutId = UUID()
        let mock = MockExerciseStorage()
        let arms = TestHelpers.makeExercise(name: "Curl", category: .arms)
        let chest = TestHelpers.makeExercise(name: "Press", category: .chest)
        mock.seedExercises([arms, chest], workoutId: workoutId)
        var moved = arms
        moved.name = "Row"
        moved.category = .back

        mock.updateExercise(moved)

        #expect(try mock.loadWorkoutExercises(for: workoutId).map(\.name) == ["Press", "Row"])
        #expect(mock.exerciseCountsByWorkout()[workoutId] == 2)
        #expect(try mock.loadWorkoutExercises(for: UUID()).isEmpty)

        mock.seedExercises([moved], workoutId: workoutId)

        #expect(try mock.loadWorkoutExercises(for: workoutId).map(\.id) == [moved.id])
        #expect(mock.exerciseCountsByWorkout()[workoutId] == 1)
    }

    @Test func exerciseCountsAreAggregatedForAllWorkoutsInOneRead() throws {
        let ws = TestHelpers.makeWorkoutStorageService(container: container)
        let workout1 = ws.workouts.first!
        let workout2 = try ws.createWorkout(name: "Second")
        let sut = ExerciseStorageService(container: container)

        sut.saveForWorkout(
            [
                TestHelpers.makeExercise(name: "Curl", category: .arms),
                TestHelpers.makeExercise(name: "Press", category: .arms),
            ],
            workoutId: workout1.id,
            category: .arms
        )
        sut.saveForWorkout(
            [TestHelpers.makeExercise(name: "Squat", category: .legs)],
            workoutId: workout2.id,
            category: .legs
        )

        let counts = sut.exerciseCountsByWorkout()

        #expect(counts[workout1.id] == 2)
        #expect(counts[workout2.id] == 1)
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
        let ws = TestHelpers.makeWorkoutStorageService(container: container)
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
