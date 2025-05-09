import Foundation

class AnalyticsViewModel: ObservableObject {
    private let storageService: AnalyticsStorageService
    
    init(storageService: AnalyticsStorageService = AnalyticsStorageService()) {
        self.storageService = storageService
    }
    
    func saveAnalytics(exerciseId: UUID, setProgress: [SetProgress], date: Date = Date()) {
        guard !setProgress.isEmpty else {
            print("No set progress to save for analytics")
            return
        }
        
        let analyticsEntry = AnalyticsEntry(
            exerciseId: exerciseId,
            date: date,
            setProgress: setProgress
        )
        
        var existingEntries = storageService.load(for: exerciseId)
        existingEntries.append(analyticsEntry)
        storageService.save(existingEntries, for: exerciseId)
        print("Saved analytics entry for exercise \(exerciseId)")
    }
    
    func loadAnalytics(for exerciseId: UUID) -> [AnalyticsEntry] {
        let entries = storageService.load(for: exerciseId)
        print("Loaded \(entries.count) analytics entries for exercise \(exerciseId)")
        return entries
    }
    
    func loadAnalytics(for exerciseId: UUID, on date: Date) -> [AnalyticsEntry] {
        let calendar = Calendar.current
        let entries = loadAnalytics(for: exerciseId)
        let filteredEntries = entries.filter { entry in
            calendar.isDate(entry.date, inSameDayAs: date)
        }
        print("Loaded \(filteredEntries.count) analytics entries for exercise \(exerciseId) on \(date)")
        return filteredEntries
    }
}
