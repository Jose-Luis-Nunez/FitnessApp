import Testing
import Foundation
import FitnessCore
import FitnessStorage
import FitnessTestSupport
@testable import FitnessWorkouts

@Suite("ImportWorkoutViewModel", .tags(.fast))
@MainActor
struct ImportWorkoutViewModelTests {

    private final class CallbackSpy {
        var importedWorkouts: [Workout] = []
        var dismissCount = 0
    }

    @MainActor
    private func makeSUT() -> (sut: ImportWorkoutViewModel, storage: MockWorkoutStorage, spy: CallbackSpy) {
        let storage = MockWorkoutStorage()
        let useCase = ImportWorkoutUseCase(workoutStorage: storage)
        let spy = CallbackSpy()
        let sut = ImportWorkoutViewModel(
            importWorkoutUseCase: useCase,
            onImported: { workout in spy.importedWorkouts.append(workout) },
            onDismiss: { spy.dismissCount += 1 }
        )
        return (sut, storage, spy)
    }

    private func makeValidEnvelopeJSON(name: String = "Push Day") throws -> String {
        let workout = Workout(name: name, selectedCategories: [.chest])
        let exercise = Exercise(
            name: "Bench",
            weight: 80,
            reps: 8,
            sets: 3,
            iconName: "defaultArmsIcon",
            category: .chest
        )
        let envelope = WorkoutShareEnvelope(
            workout: workout,
            exercises: [exercise],
            analytics: []
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(envelope)
        return String(data: data, encoding: .utf8)!
    }

    // MARK: - Initial state / disabled-rules

    @Test func importAvailabilityUsesTrimmedText() {
        let cases: [(text: String, disabled: Bool)] = [
            ("", true),
            ("   \n  \t ", true),
            ("{some text}", false),
        ]

        for testCase in cases {
            let (sut, _, _) = makeSUT()
            sut.pastedText = testCase.text
            #expect(sut.isImportDisabled == testCase.disabled)
        }
    }

    // MARK: - Successful import path

    @Test func validJsonImportTriggersCallbacksAndAddsWorkout() throws {
        let (sut, storage, spy) = makeSUT()
        let json = try makeValidEnvelopeJSON(name: "FromTest")
        sut.pastedText = "\n\t  \(json)  \n"

        sut.importTapped()

        #expect(spy.importedWorkouts.count == 1)
        #expect(spy.dismissCount == 1)
        #expect(sut.error == nil)
        #expect(storage.workouts.contains(where: { $0.name == "FromTest" }))
    }

    // MARK: - Failure paths

    @Test func invalidJsonSetsErrorAndSheetStaysOpen() {
        let (sut, _, spy) = makeSUT()
        sut.pastedText = "not actually json {"

        sut.importTapped()

        #expect(spy.importedWorkouts.isEmpty)
        #expect(spy.dismissCount == 0)
        #expect(sut.error == .invalidJSON)
    }

    @Test func unsupportedVersionSetsErrorAndSheetStaysOpen() throws {
        let (sut, _, spy) = makeSUT()
        let workout = Workout(name: "Test", selectedCategories: [.chest])
        let envelope = WorkoutShareEnvelope(
            version: 99,
            workout: workout,
            exercises: [],
            analytics: []
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        sut.pastedText = String(data: try encoder.encode(envelope), encoding: .utf8)!

        sut.importTapped()

        #expect(spy.importedWorkouts.isEmpty)
        #expect(spy.dismissCount == 0)
        #expect(sut.error == .newerVersion)
    }

    @Test func errorClearsOnNextImportAttempt() throws {
        let (sut, _, _) = makeSUT()
        // First attempt: invalid → error pill appears
        sut.pastedText = "garbage"
        sut.importTapped()
        #expect(sut.error != nil)

        // Second attempt: replace with valid JSON → error cleared by `importTapped` itself
        sut.pastedText = try makeValidEnvelopeJSON()
        sut.importTapped()

        #expect(sut.error == nil)
    }

    @Test func importTapped_disabledGuard_doesNotCallCallbacksOrSetError() {
        // When `isImportDisabled` is true (here: empty text), `importTapped()`
        // must short-circuit silently: no callbacks fire, no error is set.
        // Complements `importAvailabilityUsesTrimmedText` which tests the property in
        // isolation — this test verifies the method-side-effect of the guard.
        let (sut, _, spy) = makeSUT()
        sut.pastedText = ""
        sut.importTapped()
        #expect(spy.importedWorkouts.isEmpty)
        #expect(spy.dismissCount == 0)
        #expect(sut.error == nil, "Disabled guard must not produce an error message.")
    }
}
