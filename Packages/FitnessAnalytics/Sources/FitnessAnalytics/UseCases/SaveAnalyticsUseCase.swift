import Foundation
import FitnessCore
import Factory
import FitnessStorage

@MainActor
public struct SaveAnalyticsUseCase {
    @Injected(\.analyticsStorage) private var storageService

    public init() {}

    /// Creates a new analytics entry and appends it to the exercise's history.
    public func execute(exerciseId: UUID, setProgress: [SetProgress], date: Date = Date()) {
        guard !setProgress.isEmpty else { return }

        let analyticsEntry = AnalyticsEntry(
            exerciseId: exerciseId,
            date: date,
            setProgress: setProgress
        )

        var existingEntries = storageService.load(for: exerciseId)
        existingEntries.append(analyticsEntry)
        storageService.save(existingEntries, for: exerciseId)
    }
}
