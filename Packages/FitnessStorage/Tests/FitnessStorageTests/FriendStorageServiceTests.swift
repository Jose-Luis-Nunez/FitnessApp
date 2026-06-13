import Testing
import Foundation
import SwiftData
import FitnessCore
import FitnessTestSupport
@_spi(PersistenceUI) @testable import FitnessStorage

@Suite("FriendStorageService", .tags(.integration))
@MainActor
struct FriendStorageServiceTests {

    private let container: ModelContainer

    init() {
        container = TestHelpers.makeInMemoryContainerWithFriends()
    }

    private func makeSUT() -> FriendStorageService {
        FriendStorageService(modelContext: container.mainContext)
    }

    private func makeEnvelopeJSON(workoutName: String = "Push Day", exerciseName: String = "Bench Press") throws -> String {
        let envelope = WorkoutShareEnvelope(
            exportedAt: Date(),
            app: "FitnessApp",
            workout: Workout(name: workoutName, selectedCategories: [.chest]),
            exercises: [Exercise(name: exerciseName, weight: 80, reps: 8, sets: 3, iconName: "x", category: .chest)],
            analytics: []
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return String(decoding: try encoder.encode(envelope), as: UTF8.self)
    }

    // MARK: - Upsert

    @Test("Upsert creates a new friend with trimmed name")
    func upsertCreatesFriend() throws {
        let sut = makeSUT()
        let friend = try sut.upsertFriend(name: "  Alice  ", envelopeJSON: "{}", workoutName: "Push Day")

        #expect(friend.name == "Alice")
        #expect(friend.workoutName == "Push Day")
        #expect(sut.friends.count == 1)
        #expect(sut.friends[0].id == friend.id)
    }

    @Test("Upsert replaces in place for same normalised name (case + whitespace)")
    func upsertDedupesByNormalisedName() throws {
        let sut = makeSUT()
        let first = try sut.upsertFriend(name: "Alice", envelopeJSON: "{\"v\":1}", workoutName: "Push Day")
        let second = try sut.upsertFriend(name: "  alice ", envelopeJSON: "{\"v\":2}", workoutName: "Leg Day")

        #expect(sut.friends.count == 1, "same normalised name must not create a duplicate")
        #expect(second.id == first.id, "the existing record is updated, not replaced with a new id")
        #expect(sut.friends[0].workoutName == "Leg Day")
    }

    // MARK: - Delete

    @Test("Delete removes the friend")
    func deleteRemovesFriend() throws {
        let sut = makeSUT()
        let a = try sut.upsertFriend(name: "Alice", envelopeJSON: "{}", workoutName: "A")
        try sut.upsertFriend(name: "Bob", envelopeJSON: "{}", workoutName: "B")
        #expect(sut.friends.count == 2)

        sut.deleteFriend(id: a.id)

        #expect(sut.friends.count == 1)
        #expect(!sut.friends.contains { $0.id == a.id })
    }

    @Test("Delete of unknown id is a no-op")
    func deleteUnknownIsNoOp() throws {
        let sut = makeSUT()
        try sut.upsertFriend(name: "Alice", envelopeJSON: "{}", workoutName: "A")

        sut.deleteFriend(id: UUID())

        #expect(sut.friends.count == 1)
    }

    // MARK: - loadEnvelope

    @Test("loadEnvelope decodes the stored envelope JSON")
    func loadEnvelopeDecodes() throws {
        let sut = makeSUT()
        let json = try makeEnvelopeJSON(workoutName: "Push Day", exerciseName: "Bench Press")
        let friend = try sut.upsertFriend(name: "Alice", envelopeJSON: json, workoutName: "Push Day")

        let envelope = try sut.loadEnvelope(for: friend.id)

        #expect(envelope.workout.name == "Push Day")
        #expect(envelope.exercises.count == 1)
        #expect(envelope.exercises.first?.name == "Bench Press")
    }

    @Test("loadEnvelope throws for an unknown friend id")
    func loadEnvelopeThrowsWhenNotFound() {
        let sut = makeSUT()
        #expect(throws: (any Error).self) {
            try sut.loadEnvelope(for: UUID())
        }
    }

    // MARK: - Ordering / persistence

    @Test("friends are ordered by addedAt ascending and survive a fresh service")
    func friendsOrderedAndPersisted() throws {
        let sut = makeSUT()
        try sut.upsertFriend(name: "First", envelopeJSON: "{}", workoutName: "A")
        try sut.upsertFriend(name: "Second", envelopeJSON: "{}", workoutName: "B")

        // A fresh service over the same context must see both, in insertion order.
        let reopened = makeSUT()
        #expect(reopened.friends.map(\.name) == ["First", "Second"])
    }
}
