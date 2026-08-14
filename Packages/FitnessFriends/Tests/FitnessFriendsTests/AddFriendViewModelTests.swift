import Testing
import Foundation
import FitnessCore
import FitnessStorage
@testable import FitnessFriends

// MARK: - Mock FriendStoring

@MainActor
private final class MockFriendStorage: FriendStoring {
    var friends: [Friend] = []
    var upsertShouldThrow: WorkoutShareError?
    var capturedUpsertName: String?
    var capturedEnvelopeJSON: String?

    func upsertFriend(name: String, envelopeJSON: String, workoutName: String) throws -> Friend {
        capturedUpsertName = name
        capturedEnvelopeJSON = envelopeJSON
        if let error = upsertShouldThrow { throw error }
        let f = Friend(id: UUID(), name: name, addedAt: Date(), workoutName: workoutName)
        friends.append(f)
        return f
    }

    func deleteFriend(id: UUID) {
        friends.removeAll { $0.id == id }
    }

    func loadEnvelope(for friendId: UUID) throws -> WorkoutShareEnvelope {
        throw WorkoutShareError.persistenceFailed
    }
}

// MARK: - Helpers

private func makeValidEnvelopeJSON(workoutName: String = "Push Day") -> String {
    let workout = Workout(name: workoutName, selectedCategories: [.chest])
    let exercise = Exercise(
        id: UUID(), name: "Bench Press", weight: 80, reps: 8, sets: 3,
        seatSetting: nil, noSeats: false, isCompleted: false,
        iconName: "defaultChestIcon", category: .chest
    )
    let envelope = WorkoutShareEnvelope(
        version: WorkoutShareEnvelope.currentVersion,
        exportedAt: Date(),
        app: "FitnessApp",
        workout: workout,
        exercises: [exercise],
        analytics: []
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let data = try! encoder.encode(envelope)
    return String(data: data, encoding: .utf8)!
}

// MARK: - Tests

@Suite("AddFriendViewModel")
@MainActor
struct AddFriendViewModelTests {

    private final class CallbackSpy {
        var addedCount = 0
        var dismissCount = 0
    }

    private func makeSUT(
        storageShouldThrow: WorkoutShareError? = nil,
        importCoordinator: FriendImportCoordinator? = nil
    ) -> (sut: AddFriendViewModel, storage: MockFriendStorage, callbacks: CallbackSpy) {
        let storage = MockFriendStorage()
        storage.upsertShouldThrow = storageShouldThrow
        let useCase = ImportFriendUseCase(friendStorage: storage)
        let callbacks = CallbackSpy()
        let vm = AddFriendViewModel(
            importFriendUseCase: useCase,
            importCoordinator: importCoordinator,
            onAdded: { callbacks.addedCount += 1 },
            onDismiss: { callbacks.dismissCount += 1 }
        )
        return (vm, storage, callbacks)
    }

    private func makeTemporaryFriendFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("friend-\(UUID().uuidString).fitnessfriend")
    }

    // MARK: - isSaveDisabled

    @Test("Save availability follows trimmed name and JSON")
    func saveAvailabilityUsesTrimmedFields() {
        let cases: [(name: String, json: String, disabled: Bool)] = [
            ("", "", true),
            ("Alice", "", true),
            ("", "{}", true),
            ("Alice", makeValidEnvelopeJSON(), false),
            ("   ", "  \n  ", true),
        ]

        for testCase in cases {
            let (vm, _, _) = makeSUT()
            vm.friendName = testCase.name
            vm.pastedText = testCase.json
            #expect(vm.isSaveDisabled == testCase.disabled)
        }
    }

    // MARK: - file selection

    @Test("chooseFileTapped presents the document importer")
    func chooseFileTappedPresentsImporter() {
        let (vm, _, _) = makeSUT()

        vm.chooseFileTapped()

        #expect(vm.showingFileImporter)
    }

    @Test("Selecting a friend file populates its data and name")
    func selectingFriendFilePopulatesData() throws {
        let coordinator = FriendImportCoordinator()
        let (vm, _, _) = makeSUT(importCoordinator: coordinator)
        let url = makeTemporaryFriendFile()
        let content = #"{"version":1}"#
        try Data(content.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        vm.friendFileSelected(url)

        #expect(vm.pastedText == content)
        #expect(vm.fileName == url.deletingPathExtension().lastPathComponent)
        #expect(vm.hasData)
        #expect(vm.errorMessage == nil)
        #expect(coordinator.pendingImportJSON == nil)
        #expect(coordinator.pendingImportFileName == nil)
    }

    @Test("Selecting an unreadable friend file exposes an error")
    func selectingUnreadableFriendFileExposesError() {
        let coordinator = FriendImportCoordinator()
        let (vm, _, _) = makeSUT(importCoordinator: coordinator)
        let missingURL = makeTemporaryFriendFile()

        vm.friendFileSelected(missingURL)

        #expect(!vm.hasData)
        #expect(vm.fileName == nil)
        #expect(vm.errorMessage == .unreadableFile)
    }

    // MARK: - saveTapped: success

    @Test("saveTapped trims valid JSON, persists, and completes the flow")
    func saveTappedSuccessPersistsAndCallsCallbacks() throws {
        let (vm, storage, callbacks) = makeSUT()
        vm.errorMessage = .savingFailed
        vm.friendName = "Alice"
        vm.pastedText = "   \(makeValidEnvelopeJSON())   "

        vm.saveTapped()

        #expect(vm.errorMessage == nil)
        #expect(storage.capturedUpsertName == "Alice")
        let persistedJSON = try #require(storage.capturedEnvelopeJSON)
        #expect(!persistedJSON.hasPrefix(" "))
        #expect(!persistedJSON.hasSuffix(" "))
        #expect(callbacks.addedCount == 1)
        #expect(callbacks.dismissCount == 1)
    }

    // MARK: - saveTapped: validation errors

    @Test("saveTapped with invalid JSON sets invalidJSON error message")
    func saveTappedInvalidJSONSetsError() {
        let (vm, _, _) = makeSUT()
        vm.friendName = "Alice"
        vm.pastedText = "not json"

        vm.saveTapped()

        #expect(vm.errorMessage == .invalidJSON)
    }

    @Test("saveTapped does nothing when save is disabled")
    func saveTappedNoopWhenDisabled() {
        let (vm, storage, callbacks) = makeSUT()
        vm.friendName = ""
        vm.pastedText = ""

        vm.saveTapped()

        #expect(storage.capturedUpsertName == nil)
        #expect(vm.errorMessage == nil)
        #expect(callbacks.addedCount == 0)
        #expect(callbacks.dismissCount == 0)
    }
}
