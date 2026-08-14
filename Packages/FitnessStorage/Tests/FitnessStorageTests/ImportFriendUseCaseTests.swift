import Testing
import Foundation
import SwiftData
import FitnessCore
import FitnessTestSupport
@testable import FitnessStorageTestSupport
@_spi(PersistenceUI) @testable import FitnessStorage

@Suite("ImportFriendUseCase", .tags(.integration))
@MainActor
struct ImportFriendUseCaseTests {

    private let container: ModelContainer

    init() {
        container = TestHelpers.makeInMemoryContainerWithFriends()
    }

    private func makeFriendStorage() -> FriendStorageService {
        FriendStorageService(modelContext: container.mainContext)
    }

    private func makeSUT(storage: FriendStorageService) -> ImportFriendUseCase {
        ImportFriendUseCase(friendStorage: storage)
    }

    private func makeEnvelopeJSON(
        version: Int = WorkoutShareEnvelope.currentVersion,
        workoutName: String = "Push Day"
    ) throws -> String {
        let workout = Workout(name: workoutName, selectedCategories: [.chest])
        let exercise = Exercise(
            name: "Bench Press", weight: 80, reps: 8, sets: 3,
            iconName: "defaultChestIcon", category: .chest,
            executionMode: .bilateral
        )
        let analytics = AnalyticsEntry(
            exerciseId: exercise.id,
            date: Date(),
            setProgress: [
                SetProgress(
                    status: .completedDone,
                    currentReps: 8,
                    weight: 80,
                    side: .left,
                    logicalSetIndex: 0
                ),
                SetProgress(
                    status: .completedDone,
                    currentReps: 9,
                    weight: 80,
                    side: .right,
                    logicalSetIndex: 0
                )
            ]
        )
        let envelope = WorkoutShareEnvelope(
            version: version,
            exportedAt: Date(),
            app: "FitnessApp",
            workout: workout,
            exercises: [exercise],
            analytics: [analytics]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(envelope)
        return String(data: data, encoding: .utf8)!
    }

    // MARK: - Happy path

    @Test("Happy path: imports friend with correct name and workoutName")
    func happyPath() throws {
        let storage = makeFriendStorage()
        let sut = makeSUT(storage: storage)
        let json = try makeEnvelopeJSON(workoutName: "Push Day")

        let friend = try sut.execute(friendName: "  Alice  ", jsonString: json)

        #expect(friend.name == "Alice")
        #expect(friend.workoutName == "Push Day")
        #expect(storage.friends.count == 1)
        let storedEnvelope = try storage.loadEnvelope(for: friend.id)
        #expect(storedEnvelope.exercises.first?.executionMode == .bilateral)
        #expect(storedEnvelope.analytics.first?.setProgress.map(\.side) == [.left, .right])
    }

    // MARK: - Validation errors

    @Test("Throws invalidJSON for non-JSON text")
    func throwsInvalidJSONForGarbage() {
        let storage = makeFriendStorage()
        let sut = makeSUT(storage: storage)

        #expect(throws: WorkoutShareError.invalidJSON) {
            try sut.execute(friendName: "Bob", jsonString: "not json at all")
        }
    }

    @Test("Throws invalidJSON for empty string")
    func throwsInvalidJSONForEmptyString() {
        let storage = makeFriendStorage()
        let sut = makeSUT(storage: storage)

        #expect(throws: WorkoutShareError.invalidJSON) {
            try sut.execute(friendName: "Bob", jsonString: "")
        }
    }

    @Test("Throws unsupportedVersion for version 0")
    func throwsUnsupportedVersionZero() throws {
        let storage = makeFriendStorage()
        let sut = makeSUT(storage: storage)
        let json = try makeEnvelopeJSON(version: 0)

        #expect(throws: WorkoutShareError.unsupportedVersion(0)) {
            try sut.execute(friendName: "Bob", jsonString: json)
        }
    }

    @Test("Throws unsupportedVersion for version above current")
    func throwsUnsupportedVersionTooHigh() throws {
        let storage = makeFriendStorage()
        let sut = makeSUT(storage: storage)
        let json = try makeEnvelopeJSON(version: WorkoutShareEnvelope.currentVersion + 10)

        let expected = WorkoutShareError.unsupportedVersion(WorkoutShareEnvelope.currentVersion + 10)
        #expect(throws: expected) {
            try sut.execute(friendName: "Bob", jsonString: json)
        }
    }

    // MARK: - Re-import replaces

    @Test("Re-import with same name replaces existing friend data")
    func reimportReplacesExisting() throws {
        let storage = makeFriendStorage()
        let sut = makeSUT(storage: storage)

        let json1 = try makeEnvelopeJSON(workoutName: "Push Day")
        try sut.execute(friendName: "Alice", jsonString: json1)
        #expect(storage.friends.count == 1)
        #expect(storage.friends[0].workoutName == "Push Day")

        let json2 = try makeEnvelopeJSON(workoutName: "Leg Day")
        try sut.execute(friendName: "alice", jsonString: json2) // same name, different case

        #expect(storage.friends.count == 1)
        #expect(storage.friends[0].workoutName == "Leg Day")
    }
}
