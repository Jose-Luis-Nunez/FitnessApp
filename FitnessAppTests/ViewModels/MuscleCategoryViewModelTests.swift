import XCTest
@testable import FitnessApp

@MainActor
final class MuscleCategoryViewModelTests: XCTestCase {
    private var sut: MuscleCategoryViewModel!
    private var mockStorage: MockExerciseStorage!
    
    override func setUp() async throws {
        try await super.setUp()
        mockStorage = MockExerciseStorage()
        sut = MuscleCategoryViewModel(group: .arms, storage: mockStorage)
    }
    
    override func tearDown() async throws {
        sut = nil
        mockStorage = nil
        try await super.tearDown()
    }
    
    private func createTestExercise(
        name: String = "Rowing",
        weight: Int = 40,
        reps: Int = 11,
        sets: Int = 3
    ) -> Exercise {
        Exercise(name: name, weight: weight, reps: reps, sets: sets)
    }
    
    private func addExerciseToViewModel() -> Exercise {
        let exercise = createTestExercise()
        sut.add(exercise)
        return exercise
    }
    
    // MARK: - Storage Tests
    func test_initialization_shouldLoadExercisesFromStorage() async throws {
        // Given
        let exercise = createTestExercise()
        mockStorage.exercises = [exercise]
        
        // When
        sut = MuscleCategoryViewModel(group: .arms, storage: mockStorage)
        
        // Then
        XCTAssertEqual(sut.exercises.count, 1)
        XCTAssertEqual(sut.exercises.first?.id, exercise.id)
    }
    
    // MARK: - Exercise State Tests
    func test_startSet_shouldUpdateExerciseState() async throws {
        // Given
        let exercise = addExerciseToViewModel()
        
        // When
        sut.startSet(for: exercise)
        
        // Then
        XCTAssertTrue(sut.isSetInProgress)
        XCTAssertEqual(sut.currentExercise?.id, exercise.id)
        XCTAssertEqual(mockStorage.saveCallCount, 1) // only 
    }
    
    func test_completeSet_shouldIncrementSetCount() async throws {
        // Given
        let exercise = addExerciseToViewModel()
        sut.startSet(for: exercise)
        
        // When
        sut.completeCurrentSet()
        
        // Then
        XCTAssertFalse(sut.isSetInProgress)
        XCTAssertEqual(mockStorage.saveCallCount, 1) // only add
    }
    
    func test_completeAllSets_shouldMarkExerciseAsCompleted() async throws {
        // Given
        let exercise = addExerciseToViewModel()
        
        // When
        await completeSets(count: exercise.sets) // 3 sets
        
        // Then
        XCTAssertTrue(sut.exercises.first?.isCompleted ?? false)
        XCTAssertEqual(mockStorage.saveCallCount, 2) // add + final complete only
    }
    
    func test_resetProgress_shouldResetAllExercises() async throws {
        // Given
        let exercise = addExerciseToViewModel()
        await completeSets(count: 1) // Just one set for testing reset
        
        // When
        sut.resetProgress()
        
        // Then
        XCTAssertFalse(sut.exercises.first?.isCompleted ?? true)
        XCTAssertEqual(mockStorage.saveCallCount, 2) // add + reset only
    }
    
    func test_updateReps_shouldUpdateExerciseReps() async throws {
        // Given
        let exercise = addExerciseToViewModel()
        sut.startSet(for: exercise)
        let newReps = 8
        
        // When
        sut.updateCurrentReps(newReps)
        
        // Then
        XCTAssertEqual(sut.exercises.first?.currentReps, newReps)
        XCTAssertEqual(mockStorage.saveCallCount, 2) // add + update
    }
    
    // MARK: - Helper Methods
    private func completeSets(count: Int) async {
        for _ in 1...count {
            if let exercise = sut.exercises.first {
                sut.startSet(for: exercise)
                sut.completeCurrentSet()
            }
        }
    }
}

// MARK: - Mock Storage
private class MockExerciseStorage: ExerciseStoring {
    var exercises: [Exercise] = []
    private let lock = NSLock()
    private(set) var saveCallCount = 0
    private(set) var loadCallCount = 0
    private(set) var removeCallCount = 0
    
    func load(for group: MuscleCategoryGroup) -> [Exercise] {
        lock.lock()
        defer { lock.unlock() }
        loadCallCount += 1
        return exercises
    }
    
    func save(_ exercises: [Exercise], for group: MuscleCategoryGroup) {
        lock.lock()
        defer { lock.unlock() }
        saveCallCount += 1
        self.exercises = exercises
    }
    
    func remove(_ exercise: Exercise, from group: MuscleCategoryGroup) {
        lock.lock()
        defer { lock.unlock() }
        removeCallCount += 1
        exercises.removeAll { $0.id == exercise.id }
    }
    
    func getCallCounts() -> (save: Int, load: Int, remove: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (saveCallCount, loadCallCount, removeCallCount)
    }
}
