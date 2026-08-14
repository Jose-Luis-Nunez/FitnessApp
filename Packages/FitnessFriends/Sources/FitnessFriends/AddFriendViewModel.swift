import Foundation
import Observation
import FitnessCore
import FitnessStorage
import Factory

public enum FriendImportFailure: Equatable, Sendable {
    case unreadableFile
    case invalidJSON
    case newerVersion
    case incompleteData
    case savingFailed
}

@Observable
@MainActor
public final class AddFriendViewModel {
    public var friendName: String = ""
    public var pastedText: String = ""
    public var fileName: String?
    public var errorMessage: FriendImportFailure?
    public var showingFileImporter = false

    @ObservationIgnored private let importFriendUseCase: ImportFriendUseCase
    @ObservationIgnored private let importCoordinator: FriendImportCoordinator
    @ObservationIgnored private let onAdded: () -> Void
    @ObservationIgnored private let onDismiss: () -> Void

    public init(
        initialJSON: String? = nil,
        fileName: String? = nil,
        importFriendUseCase: ImportFriendUseCase? = nil,
        importCoordinator: FriendImportCoordinator? = nil,
        onAdded: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.pastedText = initialJSON ?? ""
        self.fileName = fileName
        self.importFriendUseCase = importFriendUseCase ?? Container.shared.importFriendUseCase()
        self.importCoordinator = importCoordinator ?? Container.shared.friendImportCoordinator()
        self.onAdded = onAdded
        self.onDismiss = onDismiss
    }

    public var isSaveDisabled: Bool {
        friendName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var hasData: Bool {
        !pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func chooseFileTapped() {
        errorMessage = nil
        showingFileImporter = true
    }

    public func friendFileSelected(_ url: URL) {
        errorMessage = nil
        importCoordinator.clearPending()
        importCoordinator.handleIncomingFile(url)

        guard let json = importCoordinator.pendingImportJSON,
              !json.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            importCoordinator.clearPending()
            fileSelectionFailed()
            return
        }

        pastedText = json
        fileName = importCoordinator.pendingImportFileName
        importCoordinator.clearPending()
    }

    public func fileSelectionFailed() {
        errorMessage = .unreadableFile
    }

    public func saveTapped() {
        guard !isSaveDisabled else { return }
        errorMessage = nil

        do {
            let trimmedJSON = pastedText.trimmingCharacters(in: .whitespacesAndNewlines)
            try importFriendUseCase.execute(friendName: friendName, jsonString: trimmedJSON)
            onAdded()
            onDismiss()
        } catch let shareError as WorkoutShareError {
            switch shareError {
            case .invalidJSON:
                errorMessage = .invalidJSON
            case .unsupportedVersion:
                errorMessage = .newerVersion
            case .schemaMismatch:
                errorMessage = .incompleteData
            case .persistenceFailed, .exportFailed:
                errorMessage = .savingFailed
            }
        } catch {
            errorMessage = .savingFailed
        }
    }
}
