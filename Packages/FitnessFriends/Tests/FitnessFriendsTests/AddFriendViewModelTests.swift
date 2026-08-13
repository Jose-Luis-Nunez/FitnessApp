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

    func upsertFriend(name: String, envelopeJSON: String, workoutName: String) throws -> Friend {
        capturedUpsertName = name
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

    private func makeSUT(
        storageShouldThrow: WorkoutShareError? = nil,
        importCoordinator: FriendImportCoordinator? = nil
    ) -> (AddFriendViewModel, MockFriendStorage, Bool, Bool) {
        let storage = MockFriendStorage()
        storage.upsertShouldThrow = storageShouldThrow
        let useCase = ImportFriendUseCase(friendStorage: storage)
        var addedCalled = false
        var dismissCalled = false
        let vm = AddFriendViewModel(
            importFriendUseCase: useCase,
            importCoordinator: importCoordinator,
            onAdded: { addedCalled = true },
            onDismiss: { dismissCalled = true }
        )
        return (vm, storage, addedCalled, dismissCalled)
    }

    private func makeTemporaryFriendFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("friend-\(UUID().uuidString).fitnessfriend")
    }

    // MARK: - isSaveDisabled

    @Test("Save is disabled when both fields are empty")
    func saveDisabledWhenBothEmpty() {
        let (vm, _, _, _) = makeSUT()
        #expect(vm.isSaveDisabled)
    }

    @Test("Save is disabled when only name is filled")
    func saveDisabledWhenOnlyNameFilled() {
        let (vm, _, _, _) = makeSUT()
        vm.friendName = "Alice"
        #expect(vm.isSaveDisabled)
    }

    @Test("Save is disabled when only JSON is filled")
    func saveDisabledWhenOnlyJSONFilled() {
        let (vm, _, _, _) = makeSUT()
        vm.pastedText = "{}"
        #expect(vm.isSaveDisabled)
    }

    @Test("Save is enabled when both fields are filled")
    func saveEnabledWhenBothFilled() {
        let (vm, _, _, _) = makeSUT()
        vm.friendName = "Alice"
        vm.pastedText = makeValidEnvelopeJSON()
        #expect(!vm.isSaveDisabled)
    }

    @Test("Save is disabled when fields contain only whitespace")
    func saveDisabledForWhitespaceOnly() {
        let (vm, _, _, _) = makeSUT()
        vm.friendName = "   "
        vm.pastedText = "  \n  "
        #expect(vm.isSaveDisabled)
    }

    // MARK: - file selection

    @Test("chooseFileTapped presents the document importer")
    func chooseFileTappedPresentsImporter() {
        let (vm, _, _, _) = makeSUT()

        vm.chooseFileTapped()

        #expect(vm.showingFileImporter)
    }

    @Test("Selecting a friend file populates its data and name")
    func selectingFriendFilePopulatesData() throws {
        let coordinator = FriendImportCoordinator()
        let (vm, _, _, _) = makeSUT(importCoordinator: coordinator)
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

    @Test("Selecting another friend file replaces the previous data")
    func selectingAnotherFriendFileReplacesData() throws {
        let coordinator = FriendImportCoordinator()
        let (vm, _, _, _) = makeSUT(importCoordinator: coordinator)
        let firstURL = makeTemporaryFriendFile()
        let secondURL = makeTemporaryFriendFile()
        try Data("first".utf8).write(to: firstURL)
        try Data("second".utf8).write(to: secondURL)
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }

        vm.friendFileSelected(firstURL)
        vm.friendFileSelected(secondURL)

        #expect(vm.pastedText == "second")
        #expect(vm.fileName == secondURL.deletingPathExtension().lastPathComponent)
    }

    @Test("Selecting an unreadable friend file exposes an error")
    func selectingUnreadableFriendFileExposesError() {
        let coordinator = FriendImportCoordinator()
        let (vm, _, _, _) = makeSUT(importCoordinator: coordinator)
        let missingURL = makeTemporaryFriendFile()

        vm.friendFileSelected(missingURL)

        #expect(!vm.hasData)
        #expect(vm.fileName == nil)
        #expect(vm.errorMessage == "The selected friend file could not be read.")
    }

    // MARK: - saveTapped: success

    @Test("saveTapped with valid JSON clears error")
    func saveTappedSuccessNoError() {
        let (vm, _, _, _) = makeSUT()
        vm.errorMessage = "Previous error"
        vm.friendName = "Alice"
        vm.pastedText = makeValidEnvelopeJSON()

        vm.saveTapped()

        #expect(vm.errorMessage == nil)
    }

    // MARK: - saveTapped: validation errors

    @Test("saveTapped with invalid JSON sets invalidJSON error message")
    func saveTappedInvalidJSONSetsError() {
        let (vm, _, _, _) = makeSUT()
        vm.friendName = "Alice"
        vm.pastedText = "not json"

        vm.saveTapped()

        #expect(vm.errorMessage == WorkoutShareError.invalidJSON.errorDescription)
    }

    @Test("saveTapped does nothing when save is disabled")
    func saveTappedNoopWhenDisabled() {
        let (vm, storage, _, _) = makeSUT()
        vm.friendName = ""
        vm.pastedText = ""

        vm.saveTapped()

        #expect(storage.capturedUpsertName == nil)
        #expect(vm.errorMessage == nil)
    }

    @Test("saveTapped trims whitespace from pastedText before import")
    func saveTappedTrimsJSON() {
        let (vm, _, _, _) = makeSUT()
        vm.friendName = "Alice"
        vm.pastedText = "   \(makeValidEnvelopeJSON())   "

        vm.saveTapped() // should succeed, not throw invalidJSON

        #expect(vm.errorMessage == nil)
    }
}
