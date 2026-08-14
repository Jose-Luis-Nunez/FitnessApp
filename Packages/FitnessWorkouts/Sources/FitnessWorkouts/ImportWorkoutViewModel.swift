import Foundation
import Observation
import UIKit
import FitnessCore
import FitnessStorage
import Factory

public enum WorkoutImportFailure: Equatable, Sendable {
    case invalidJSON
    case newerVersion
    case incompleteData
    case savingFailed
}

@Observable
@MainActor
public final class ImportWorkoutViewModel {
    public var pastedText: String = ""
    public var error: WorkoutImportFailure?

    @ObservationIgnored private let importWorkoutUseCase: ImportWorkoutUseCase
    @ObservationIgnored private let onImported: (Workout) -> Void
    @ObservationIgnored private let onDismiss: () -> Void

    public init(
        importWorkoutUseCase: ImportWorkoutUseCase? = nil,
        initialText: String? = nil,
        onImported: @escaping (Workout) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.importWorkoutUseCase = importWorkoutUseCase ?? Container.shared.importWorkoutUseCase()
        self.onImported = onImported
        self.onDismiss = onDismiss
        if let initialText, !initialText.isEmpty {
            self.pastedText = initialText
        }
    }

    /// Disabled when there's nothing to import. Import itself is synchronous,
    /// so there is no in-flight state to track here — the work either succeeds
    /// (sheet dismisses via `onDismiss`) or fails (`error` populated,
    /// sheet stays open) within a single run-loop tick.
    public var isImportDisabled: Bool {
        pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Reads the system clipboard via an explicit user gesture. iOS surfaces a
    /// privacy banner when this fires — acceptable because the user just
    /// tapped a button. Never call this on `onAppear` / autoload.
    public func pasteFromClipboard() {
        error = nil
        if let clipboard = UIPasteboard.general.string, !clipboard.isEmpty {
            pastedText = clipboard
        }
    }

    /// Drives the import. On success the parent is notified via `onImported`
    /// and the sheet is dismissed via `onDismiss`. On failure the sheet stays
    /// open with `error` populated so the user can correct the input.
    public func importTapped() {
        guard !isImportDisabled else { return }
        error = nil

        do {
            let trimmed = pastedText.trimmingCharacters(in: .whitespacesAndNewlines)
            let workout = try importWorkoutUseCase.execute(jsonString: trimmed)
            onImported(workout)
            onDismiss()
        } catch let shareError as WorkoutShareError {
            switch shareError {
            case .invalidJSON:
                error = .invalidJSON
            case .unsupportedVersion:
                error = .newerVersion
            case .schemaMismatch:
                error = .incompleteData
            case .persistenceFailed, .exportFailed:
                error = .savingFailed
            }
        } catch {
            self.error = .savingFailed
        }
    }
}
