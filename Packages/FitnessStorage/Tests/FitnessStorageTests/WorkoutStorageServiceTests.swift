import Testing
import Foundation
import SwiftData
import FitnessCore
@_spi(PersistenceUI) @testable import FitnessStorage
import Factory

// MARK: - Spy for tracking ExerciseStoring calls

@MainActor
private final class SpyExerciseStorage: ExerciseStoring {
    var exercisesByKey: [String: [Exercise]] = [:]
    private(set) var changeVersion: Int = 0
    private(set) var saveForWorkoutCalls: [(exercises: [Exercise], workoutId: UUID, category: MuscleCategoryGroup)] = []
    private(set) var loadForWorkoutCalls: [(workoutId: UUID, category: MuscleCategoryGroup)] = []

    func loadForWorkout(workoutId: UUID, category: MuscleCategoryGroup) -> [Exercise] {
        loadForWorkoutCalls.append((workoutId, category))
        return exercisesByKey[key(workoutId, category)] ?? []
    }

    func saveForWorkout(_ exercises: [Exercise], workoutId: UUID, category: MuscleCategoryGroup) {
        saveForWorkoutCalls.append((exercises, workoutId, category))
        exercisesByKey[key(workoutId, category)] = exercises
        changeVersion += 1
    }

    func seed(_ exercises: [Exercise], workoutId: UUID, category: MuscleCategoryGroup) {
        exercisesByKey[key(workoutId, category)] = exercises
    }

    private func key(_ workoutId: UUID, _ category: MuscleCategoryGroup) -> String {
        "\(workoutId)-\(category.rawValue)"
    }
}

@Suite("WorkoutStorageService CRUD")
@MainActor
struct WorkoutStorageServiceTests {

    private let container: ModelContainer
    private let defaults: UserDefaults
    private let exerciseStorage: SpyExerciseStorage

    init() {
        container = TestHelpers.makeInMemoryContainer()
        defaults = TestHelpers.makeIsolatedDefaults()
        exerciseStorage = SpyExerciseStorage()
    }

    private func makeSUT() -> WorkoutStorageService {
        WorkoutStorageService(container: container, defaults: defaults, exerciseStorage: exerciseStorage)
    }

    // MARK: - Init / Auto-Create

    @Test func createsDefaultWorkoutOnEmptyDatabase() {
        let sut = makeSUT()
        #expect(sut.workouts.count == 1)
        #expect(sut.workouts.first?.name == "Workout 1")
        #expect(sut.currentWorkout != nil)
        #expect(sut.defaultWorkout != nil)
        #expect(sut.currentWorkout?.id == sut.defaultWorkout?.id)
    }

    // MARK: - Create

    @Test func createWorkoutPersistsAndAppearsInList() {
        let sut = makeSUT()
        let created = sut.createWorkout(name: "Legs Day", selectedCategories: [.legs, .abs])

        #expect(sut.workouts.contains { $0.id == created.id })

        let sut2 = makeSUT()
        #expect(sut2.workouts.contains { $0.id == created.id })
        let reloaded = sut2.workouts.first { $0.id == created.id }
        #expect(reloaded?.name == "Legs Day")
        #expect(reloaded?.selectedCategories == [.legs, .abs])
    }

    // MARK: - Rename

    @Test func renameWorkoutPersistsNewName() {
        let sut = makeSUT()
        let created = sut.createWorkout(name: "Old Name")
        sut.renameWorkout(created, newName: "New Name")

        let reloaded = makeSUT()
        let found = reloaded.workouts.first { $0.id == created.id }
        #expect(found?.name == "New Name")
    }

    // MARK: - Delete

    @Test func deleteWorkoutRemovesFromPersistence() {
        let sut = makeSUT()
        let toDelete = sut.createWorkout(name: "To Delete")
        let countBefore = sut.workouts.count
        sut.deleteWorkout(toDelete)

        #expect(sut.workouts.count == countBefore - 1)
        #expect(!sut.workouts.contains { $0.id == toDelete.id })

        let reloaded = makeSUT()
        #expect(!reloaded.workouts.contains { $0.id == toDelete.id })
    }

    @Test func deleteCurrentWorkoutFallsBackToFirst() {
        let sut = makeSUT()
        let second = sut.createWorkout(name: "Second")
        sut.setCurrentWorkout(second)
        #expect(sut.currentWorkout?.id == second.id)

        sut.deleteWorkout(second)
        #expect(sut.currentWorkout != nil)
        #expect(sut.currentWorkout?.id != second.id)
    }

    // MARK: - Current / Default Tracking

    @Test func setCurrentWorkoutPersistsAcrossReloads() {
        let sut = makeSUT()
        let second = sut.createWorkout(name: "Second")
        sut.setCurrentWorkout(second)

        let reloaded = makeSUT()
        #expect(reloaded.currentWorkout?.id == second.id)
    }

    @Test func setAsDefaultWorkoutPersistsAcrossReloads() {
        let sut = makeSUT()
        let second = sut.createWorkout(name: "Second")
        sut.setAsDefaultWorkout(second)

        let reloaded = makeSUT()
        #expect(reloaded.defaultWorkout?.id == second.id)
    }

    @Test func removeAsDefaultWorkoutClearsDefault() {
        let sut = makeSUT()
        #expect(sut.defaultWorkout != nil)

        sut.removeAsDefaultWorkout()
        #expect(sut.defaultWorkout == nil)

        let reloaded = makeSUT()
        #expect(reloaded.defaultWorkout == nil)
    }

    // MARK: - Duplicate

    @Test func duplicateWorkoutCreatesIndependentCopy() {
        let sut = makeSUT()
        let original = sut.workouts.first!
        let duplicate = sut.duplicateWorkout(original)

        #expect(duplicate.id != original.id)
        #expect(duplicate.name.contains("Copy"))
        #expect(sut.workouts.contains { $0.id == duplicate.id })
    }

    @Test func duplicateWorkoutCopiesExercisesPerCategory() {
        let sut = makeSUT()
        let original = sut.createWorkout(
            name: "Full Body",
            selectedCategories: [.arms, .chest]
        )

        let armExercise = TestHelpers.makeExercise(name: "Curl", category: .arms)
        let chestExercise = TestHelpers.makeExercise(name: "Bench", category: .chest)
        exerciseStorage.seed([armExercise], workoutId: original.id, category: .arms)
        exerciseStorage.seed([chestExercise], workoutId: original.id, category: .chest)

        let duplicate = sut.duplicateWorkout(original)

        let saveCalls = exerciseStorage.saveForWorkoutCalls
        let armsSave = saveCalls.first { $0.category == .arms }
        let chestSave = saveCalls.first { $0.category == .chest }

        #expect(armsSave != nil)
        #expect(armsSave?.workoutId == duplicate.id)
        #expect(armsSave?.exercises.count == 1)
        #expect(armsSave?.exercises.first?.name == "Curl")

        #expect(chestSave != nil)
        #expect(chestSave?.workoutId == duplicate.id)
        #expect(chestSave?.exercises.count == 1)
        #expect(chestSave?.exercises.first?.name == "Bench")
    }

    @Test func duplicateWorkoutSkipsEmptyCategories() {
        let sut = makeSUT()
        let original = sut.createWorkout(
            name: "Arms Only",
            selectedCategories: [.arms, .legs]
        )

        let armExercise = TestHelpers.makeExercise(name: "Curl", category: .arms)
        exerciseStorage.seed([armExercise], workoutId: original.id, category: .arms)

        _ = sut.duplicateWorkout(original)

        let saveCalls = exerciseStorage.saveForWorkoutCalls
        #expect(saveCalls.count == 1)
        #expect(saveCalls.first?.category == .arms)
    }
}
