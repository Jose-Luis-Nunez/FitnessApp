import Testing
import Foundation
import FitnessCore
import FitnessStorage
@testable import FitnessFriends

// MARK: - Mocks

@MainActor
private final class MockFriendStorage: FriendStoring {
    var friends: [Friend] = []
    var deletedIds: [UUID] = []

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
        throw WorkoutShareError.persistenceFailed
    }
}

@MainActor
private final class MockWorkoutStorage: WorkoutStoring {
    var workouts: [Workout] = []
    var currentWorkout: Workout?
    var defaultWorkout: Workout?

    func createWorkout(name: String, selectedCategories: Set<MuscleCategoryGroup>) -> Workout {
        let w = Workout(name: name, selectedCategories: selectedCategories)
        workouts.append(w)
        return w
    }
    func duplicateWorkout(_ workout: Workout) -> Workout { workout }
    func importWorkout(_ workout: Workout, exercises: [Exercise], analytics: [AnalyticsEntry]) -> Workout { workout }
    func deleteWorkout(_ workout: Workout) { workouts.removeAll { $0.id == workout.id } }
    func updateWorkout(_ workout: Workout) {}
    func setCurrentWorkout(_ workout: Workout) { currentWorkout = workout }
    func setAsDefaultWorkout(_ workout: Workout) { defaultWorkout = workout }
    func removeAsDefaultWorkout() { defaultWorkout = nil }
    func renameWorkout(_ workout: Workout, newName: String) {}
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
        currentWorkout: Workout? = nil
    ) -> (FriendsViewModel, MockFriendStorage, MockWorkoutStorage) {
        let friendStorage = MockFriendStorage()
        friendStorage.friends = friends
        let workoutStorage = MockWorkoutStorage()
        workoutStorage.currentWorkout = currentWorkout
        let vm = FriendsViewModel(
            friendStorage: friendStorage,
            workoutStorage: workoutStorage
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

    @Test("Does not auto-select when multiple friends exist")
    func noAutoSelectWithMultipleFriends() {
        let friends = [makeFriend(name: "Alice"), makeFriend(name: "Bob")]
        let (vm, _, _) = makeSUT(friends: friends)

        vm.toggleExpanded()
        #expect(vm.selectedFriendId == nil)
    }

    @Test("Does not auto-select when no friends exist")
    func noAutoSelectWithNoFriends() {
        let (vm, _, _) = makeSUT(friends: [])
        vm.toggleExpanded()
        #expect(vm.selectedFriendId == nil)
    }

    // MARK: - selectFriend

    @Test("selectFriend sets selectedFriendId")
    func selectFriendSetsId() {
        let friend = makeFriend()
        let (vm, _, _) = makeSUT(friends: [friend])

        vm.selectFriend(friend)
        #expect(vm.selectedFriendId == friend.id)
    }

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

    // MARK: - friends computed property

    @Test("friends reads from friendStorage")
    func friendsComputedProperty() {
        let friend = makeFriend()
        let (vm, storage, _) = makeSUT(friends: [friend])

        #expect(vm.friends.count == 1)
        #expect(vm.friends[0].id == friend.id)

        storage.friends.append(makeFriend(name: "Bob"))
        #expect(vm.friends.count == 2)
    }
}
