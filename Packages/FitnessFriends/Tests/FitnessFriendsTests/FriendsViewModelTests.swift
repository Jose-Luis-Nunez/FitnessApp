import Testing
import Foundation
import FitnessCore
import FitnessStorage
import FitnessTestSupport
@testable import FitnessFriends

// MARK: - Mocks

@MainActor
private final class MockFriendStorage: FriendStoring {
    var friends: [Friend] = []
    var deletedIds: [UUID] = []
    var envelopeToLoad: WorkoutShareEnvelope?
    var loadEnvelopeError: Error?

    func upsertFriend(name: String, envelopeJSON: String, workoutName: String) throws -> Friend {
        let f = Friend(id: UUID(), name: name, addedAt: Date(), workoutName: workoutName)
        friends.append(f)
        return f
    }

    func deleteFriend(id: UUID) {
        deletedIds.append(id)
        friends.removeAll { $0.id == id }
    }

    func loadEnvelope(for friendId: UUID) throws -> WorkoutShareEnvelope {
        if let loadEnvelopeError { throw loadEnvelopeError }
        if let envelopeToLoad { return envelopeToLoad }
        throw WorkoutShareError.persistenceFailed
    }
}

// MARK: - Tests

@Suite("FriendsViewModel")
@MainActor
struct FriendsViewModelTests {

    private func makeFriend(name: String = "Alice") -> Friend {
        Friend(id: UUID(), name: name, addedAt: Date(), workoutName: "Push Day")
    }

    private func makeSUT(
        friends: [Friend] = [],
        currentWorkout: Workout? = nil,
        envelope: WorkoutShareEnvelope? = nil,
        loadEnvelopeError: Error? = nil
    ) -> (FriendsViewModel, MockFriendStorage, MockWorkoutStorage) {
        let friendStorage = MockFriendStorage()
        friendStorage.friends = friends
        friendStorage.envelopeToLoad = envelope
        friendStorage.loadEnvelopeError = loadEnvelopeError
        let workoutStorage = MockWorkoutStorage()
        workoutStorage.currentWorkout = currentWorkout
        let exerciseStorage = MockExerciseStorage()
        let totalAnalyticsStorage = MockTotalAnalyticsStorage(
            analyticsStorage: MockAnalyticsStorage(),
            exerciseStorage: exerciseStorage,
            workoutStorage: workoutStorage
        )
        let vm = FriendsViewModel(
            friendStorage: friendStorage,
            workoutStorage: workoutStorage,
            exerciseStorage: exerciseStorage,
            loadFriendComparisonUseCase: LoadFriendComparisonUseCase(
                friendStorage: friendStorage,
                exerciseStorage: exerciseStorage,
                totalAnalyticsStorage: totalAnalyticsStorage
            )
        )
        return (vm, friendStorage, workoutStorage)
    }

    // MARK: - toggleExpanded

    @Test("toggleExpanded flips isExpanded")
    func toggleExpandedFlipsState() {
        let (vm, _, _) = makeSUT()
        #expect(!vm.isExpanded)
        vm.toggleExpanded()
        #expect(vm.isExpanded)
        vm.toggleExpanded()
        #expect(!vm.isExpanded)
    }

    @Test("Auto-selects the only friend when expanded with one friend")
    func autoSelectsWhenOneFriend() {
        let friend = makeFriend()
        let (vm, _, _) = makeSUT(friends: [friend])

        #expect(vm.selectedFriendId == nil)
        vm.toggleExpanded()
        #expect(vm.selectedFriendId == friend.id)
    }

    @Test("Does not auto-select unless exactly one friend exists")
    func noAutoSelectWithoutExactlyOneFriend() {
        for friends in [[], [makeFriend(name: "Alice"), makeFriend(name: "Bob")]] {
            let (vm, _, _) = makeSUT(friends: friends)

            vm.toggleExpanded()

            #expect(vm.selectedFriendId == nil)
        }
    }

    // MARK: - selectFriend

    @Test("selectFriend switches selection between friends")
    func selectFriendSwitches() {
        let alice = makeFriend(name: "Alice")
        let bob = makeFriend(name: "Bob")
        let (vm, _, _) = makeSUT(friends: [alice, bob])

        vm.selectFriend(alice)
        #expect(vm.selectedFriendId == alice.id)

        vm.selectFriend(bob)
        #expect(vm.selectedFriendId == bob.id)
    }

    @Test("selectFriend publishes a comparison for the selected friend")
    func selectFriendLoadsComparison() async throws {
        let friend = makeFriend()
        let workout = Workout(name: "Mine")
        let envelope = WorkoutShareEnvelope(
            workout: Workout(name: "Friend workout"),
            exercises: [],
            analytics: []
        )
        let (vm, _, _) = makeSUT(
            friends: [friend],
            currentWorkout: workout,
            envelope: envelope
        )

        vm.selectFriend(friend)
        try await waitUntil { vm.comparison != nil }

        #expect(vm.selectedFriendId == friend.id)
        #expect(vm.comparison?.friendMetrics.totalExercises == 0)
        #expect(!vm.comparisonFailed)
    }

    @Test("selectFriend exposes comparison loading failures")
    func selectFriendReportsComparisonFailure() async throws {
        let friend = makeFriend()
        let (vm, _, _) = makeSUT(
            friends: [friend],
            currentWorkout: Workout(name: "Mine"),
            loadEnvelopeError: WorkoutShareError.invalidJSON
        )

        vm.selectFriend(friend)
        try await waitUntil { vm.comparisonFailed }

        #expect(vm.comparison == nil)
    }

    // MARK: - deleteFriend

    @Test("deleteFriend clears selection when selected friend is deleted")
    func deleteFriendClearsSelection() {
        let friend = makeFriend()
        let (vm, storage, _) = makeSUT(friends: [friend])

        vm.selectedFriendId = friend.id
        vm.deleteFriend(friend)

        #expect(vm.selectedFriendId == nil)
        #expect(vm.comparison == nil)
        #expect(storage.deletedIds.contains(friend.id))
    }

    @Test("deleteFriend keeps selection when a different friend is deleted")
    func deleteFriendKeepsSelectionForOther() {
        let alice = makeFriend(name: "Alice")
        let bob = makeFriend(name: "Bob")
        let (vm, _, _) = makeSUT(friends: [alice, bob])

        vm.selectedFriendId = alice.id
        vm.deleteFriend(bob)

        #expect(vm.selectedFriendId == alice.id)
    }

    // MARK: - friendAdded

    @Test("friendAdded auto-selects if exactly one friend remains")
    func friendAddedAutoSelectsOneFriend() {
        let friend = makeFriend()
        let (vm, storage, _) = makeSUT()
        storage.friends = [friend]

        vm.friendAdded()

        #expect(vm.selectedFriendId == friend.id)
    }

    @Test("friendAdded does not select when multiple friends exist")
    func friendAddedNoSelectMultipleFriends() {
        let (vm, storage, _) = makeSUT()
        storage.friends = [makeFriend(name: "Alice"), makeFriend(name: "Bob")]

        vm.friendAdded()

        #expect(vm.selectedFriendId == nil)
    }

    // MARK: - requestExport

    @Test("requestExport sets showingExportPicker to true")
    func requestExportSetsFlag() {
        let (vm, _, _) = makeSUT()
        #expect(!vm.showingExportPicker)
        vm.requestExport()
        #expect(vm.showingExportPicker)
    }

    // MARK: - friend import

    @Test("Friend import lifecycle snapshots and clears presentation data")
    func friendImportLifecycle() {
        let (vm, _, _) = makeSUT()

        vm.requestFriendImport()

        #expect(vm.showingAddFriend)
        #expect(vm.pendingFriendJSON == nil)
        #expect(vm.pendingFriendFileName == nil)

        vm.receiveFriendImport(json: "{\"version\":1}", fileName: "Alice")

        #expect(vm.pendingFriendJSON == "{\"version\":1}")
        #expect(vm.pendingFriendFileName == "Alice")
        #expect(vm.showingAddFriend)

        vm.friendImportDidDismiss()

        #expect(vm.pendingFriendJSON == nil)
        #expect(vm.pendingFriendFileName == nil)
    }

    @Test("receiveFriendImport rejects an empty payload with an error")
    func receiveFriendImportRejectsEmptyPayload() {
        let (vm, _, _) = makeSUT()

        vm.receiveFriendImport(json: "  \n  ", fileName: "Empty")

        #expect(vm.pendingFriendJSON == nil)
        #expect(vm.pendingFriendFileName == nil)
        #expect(!vm.showingAddFriend)
        #expect(vm.importFailed)
    }

}
