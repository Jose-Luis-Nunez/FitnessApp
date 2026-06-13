import Foundation
import Observation
import FitnessCore
import FitnessStorage
import Factory

@Observable
@MainActor
public final class AddFriendViewModel {
    public var friendName: String = ""
    public var pastedText: String = ""
    public var fileName: String?
    public var errorMessage: String?

    @ObservationIgnored private let importFriendUseCase: ImportFriendUseCase
    @ObservationIgnored private let onAdded: () -> Void
    @ObservationIgnored private let onDismiss: () -> Void

    public init(
        initialJSON: String? = nil,
        fileName: String? = nil,
        importFriendUseCase: ImportFriendUseCase? = nil,
        onAdded: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.pastedText = initialJSON ?? ""
        self.fileName = fileName
        self.importFriendUseCase = importFriendUseCase ?? Container.shared.importFriendUseCase()
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

    public func saveTapped() {
        guard !isSaveDisabled else { return }
        errorMessage = nil

        do {
            let trimmedJSON = pastedText.trimmingCharacters(in: .whitespacesAndNewlines)
            try importFriendUseCase.execute(friendName: friendName, jsonString: trimmedJSON)
            onAdded()
            onDismiss()
        } catch let error as WorkoutShareError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = WorkoutShareError.persistenceFailed.errorDescription
        }
    }
}
