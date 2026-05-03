import Foundation
import FitnessCore
import Factory
import FitnessStorage

@MainActor
public struct SaveOrReplaceAnalyticsUseCase {
    private let storageService: AnalyticsStoring

    public init(analyticsStorage: AnalyticsStoring? = nil) {
        self.storageService = analyticsStorage ?? Container.shared.analyticsStorage()
    }

    /// Finds an existing entry for the same date and replaces it, or appends a new one.
    public func execute(exerciseId: UUID, setProgress: [SetProgress], date: Date) {
        guard !setProgress.isEmpty else { return }

        let analyticsEntry = AnalyticsEntry(
            exerciseId: exerciseId,
            date: date,
            setProgress: setProgress
        )

        var existingEntries = storageService.load(for: exerciseId)
        let calendar = Calendar.current

        if let idx = existingEntries.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            existingEntries[idx] = analyticsEntry
        } else {
            existingEntries.append(analyticsEntry)
        }

        storageService.save(existingEntries, for: exerciseId)
    }
}
