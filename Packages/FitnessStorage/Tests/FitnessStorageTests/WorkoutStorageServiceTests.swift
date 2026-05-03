import Testing
import Foundation
import SwiftData
import FitnessCore
import Mockable
@_spi(PersistenceUI) @testable import FitnessStorage
import Factory

@Suite("WorkoutStorageService CRUD")
@MainActor
struct WorkoutStorageServiceTests {

    private let container: ModelContainer
    private let defaults: UserDefaults
    private let exerciseStorage: MockExerciseStoring

    init() {
        container = TestHelpers.makeInMemoryContainer()
        defaults = TestHelpers.makeIsolatedDefaults()
        exerciseStorage = TestHelpers.makeNoOpExerciseStoring()
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
        let spy = MockExerciseStoring(policy: .relaxedVoid)
        let armExercise = TestHelpers.makeExercise(name: "Curl", category: .arms)
        let chestExercise = TestHelpers.makeExercise(name: "Bench", category: .chest)

        given(spy).loadForWorkout(workoutId: .any, category: .value(.arms)).willReturn([armExercise])
        given(spy).loadForWorkout(workoutId: .any, category: .value(.chest)).willReturn([chestExercise])
        given(spy).loadForWorkout(workoutId: .any, category: .any).willReturn([])

        let sut = WorkoutStorageService(container: container, defaults: defaults, exerciseStorage: spy)
        let original = sut.createWorkout(
            name: "Full Body",
            selectedCategories: [.arms, .chest]
        )

        let duplicate = sut.duplicateWorkout(original)

        verify(spy)
            .saveForWorkout(.any, workoutId: .any, category: .any)
            .called(.atLeastOnce)
        verify(spy)
            .saveForWorkout(.any, workoutId: .value(duplicate.id), category: .value(.arms))
            .called(.atLeastOnce)
        verify(spy)
            .saveForWorkout(.any, workoutId: .value(duplicate.id), category: .value(.chest))
            .called(.atLeastOnce)
    }

    @Test func duplicateWorkoutSkipsEmptyCategories() {
        let spy = MockExerciseStoring(policy: .relaxedVoid)
        let armExercise = TestHelpers.makeExercise(name: "Curl", category: .arms)

        given(spy).loadForWorkout(workoutId: .any, category: .value(.arms)).willReturn([armExercise])
        given(spy).loadForWorkout(workoutId: .any, category: .any).willReturn([])

        let sut = WorkoutStorageService(container: container, defaults: defaults, exerciseStorage: spy)
        let original = sut.createWorkout(
            name: "Arms Only",
            selectedCategories: [.arms, .legs]
        )

        _ = sut.duplicateWorkout(original)

        verify(spy)
            .saveForWorkout(.any, workoutId: .any, category: .value(.arms))
            .called(.atLeastOnce)
        verify(spy)
            .saveForWorkout(.any, workoutId: .any, category: .value(.legs))
            .called(.never)
    }
}
