import Testing
import Foundation
import SwiftData
import FitnessCore
import FitnessTestSupport
import Mockable
@_spi(PersistenceUI) @testable import FitnessStorage
@Suite("WorkoutStorageService CRUD", .tags(.integration))
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
        WorkoutStorageService(container: container, defaults: defaults, exerciseStorage: exerciseStorage, analyticsStorage: TestHelpers.makeNoOpAnalyticsStoring())
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

    @Test func createWorkoutPersistsAndAppearsInList() throws {
        let sut = makeSUT()
        let created = try sut.createWorkout(name: "Legs Day", selectedCategories: [.legs, .abs])

        #expect(sut.workouts.contains { $0.id == created.id })

        let sut2 = makeSUT()
        #expect(sut2.workouts.contains { $0.id == created.id })
        let reloaded = sut2.workouts.first { $0.id == created.id }
        #expect(reloaded?.name == "Legs Day")
        #expect(reloaded?.selectedCategories == [.legs, .abs])
    }

    @Test func workoutTypePersistsAcrossReloads() throws {
        let sut = makeSUT()
        let created = try sut.createWorkout(name: "Leg Day", type: .leg)

        let reloaded = makeSUT().workouts.first { $0.id == created.id }
        #expect(reloaded?.type == .leg)
    }

    @Test func updatedWorkoutTypePersistsAcrossReloads() throws {
        let sut = makeSUT()
        var created = try sut.createWorkout(name: "Changing Plan", type: .pull)
        created.type = .full

        sut.updateWorkout(created)

        let reloaded = makeSUT().workouts.first { $0.id == created.id }
        #expect(reloaded?.type == .full)
    }

    @Test func unknownPersistedWorkoutTypeFallsBackToIndividual() {
        let model = WorkoutModel(
            id: UUID(),
            name: "Future Workout",
            selectedCategories: [],
            createdDate: .now,
            lastModified: .now,
            typeRaw: "future-type"
        )

        #expect(model.toDomain().type == .individual)
    }

    // MARK: - Rename

    @Test func renameWorkoutPersistsNewName() throws {
        let sut = makeSUT()
        let created = try sut.createWorkout(name: "Old Name")
        sut.renameWorkout(created, newName: "New Name")

        let reloaded = makeSUT()
        let found = reloaded.workouts.first { $0.id == created.id }
        #expect(found?.name == "New Name")
    }

    // MARK: - Delete

    @Test func deleteWorkoutRemovesFromPersistence() throws {
        let sut = makeSUT()
        let toDelete = try sut.createWorkout(name: "To Delete")
        let countBefore = sut.workouts.count
        sut.deleteWorkout(toDelete)

        #expect(sut.workouts.count == countBefore - 1)
        #expect(!sut.workouts.contains { $0.id == toDelete.id })

        let reloaded = makeSUT()
        #expect(!reloaded.workouts.contains { $0.id == toDelete.id })
    }

    @Test func deleteCurrentWorkoutFallsBackToFirst() throws {
        let sut = makeSUT()
        let second = try sut.createWorkout(name: "Second")
        sut.setCurrentWorkout(second)
        #expect(sut.currentWorkout?.id == second.id)

        sut.deleteWorkout(second)
        #expect(sut.currentWorkout != nil)
        #expect(sut.currentWorkout?.id != second.id)
    }

    // MARK: - Current / Default Tracking

    @Test func setCurrentWorkoutPersistsAcrossReloads() throws {
        let sut = makeSUT()
        let second = try sut.createWorkout(name: "Second")
        sut.setCurrentWorkout(second)

        let reloaded = makeSUT()
        #expect(reloaded.currentWorkout?.id == second.id)
    }

    @Test func setAsDefaultWorkoutPersistsAcrossReloads() throws {
        let sut = makeSUT()
        let second = try sut.createWorkout(name: "Second")
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
        var original = sut.workouts.first!
        original.type = .leg
        sut.updateWorkout(original)
        let duplicate = sut.duplicateWorkout(original)

        #expect(duplicate.id != original.id)
        #expect(duplicate.name.contains("Copy"))
        #expect(duplicate.type == .leg)
        #expect(sut.workouts.contains { $0.id == duplicate.id })
        #expect(makeSUT().workouts.first { $0.id == duplicate.id }?.type == .leg)
    }

    @Test func duplicateWorkoutCopiesExercisesPerCategory() throws {
        let spy = MockExerciseStoring(policy: .relaxedVoid)
        let armExercise = TestHelpers.makeExercise(name: "Curl", category: .arms)
        let chestExercise = TestHelpers.makeExercise(name: "Bench", category: .chest)

        given(spy).loadForWorkout(workoutId: .any, category: .value(.arms)).willReturn([armExercise])
        given(spy).loadForWorkout(workoutId: .any, category: .value(.chest)).willReturn([chestExercise])
        given(spy).loadForWorkout(workoutId: .any, category: .any).willReturn([])

        let sut = WorkoutStorageService(container: container, defaults: defaults, exerciseStorage: spy, analyticsStorage: TestHelpers.makeNoOpAnalyticsStoring())
        let original = try sut.createWorkout(
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

    @Test func duplicateWorkoutSkipsEmptyCategories() throws {
        let spy = MockExerciseStoring(policy: .relaxedVoid)
        let armExercise = TestHelpers.makeExercise(name: "Curl", category: .arms)

        given(spy).loadForWorkout(workoutId: .any, category: .value(.arms)).willReturn([armExercise])
        given(spy).loadForWorkout(workoutId: .any, category: .any).willReturn([])

        let sut = WorkoutStorageService(container: container, defaults: defaults, exerciseStorage: spy, analyticsStorage: TestHelpers.makeNoOpAnalyticsStoring())
        let original = try sut.createWorkout(
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
