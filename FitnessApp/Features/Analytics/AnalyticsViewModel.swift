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
    
    func allDatesWithData(for exerciseId: UUID) -> Set<Date> {
        let entries = loadAnalytics(for: exerciseId)
        let calendar = Calendar.current
        let uniqueDates = entries.map { calendar.startOfDay(for: $0.date) }
        return Set(uniqueDates)
    }
    
    func loadAnalyticsDates(for exerciseId: UUID) -> [Date] {
        let entries = storageService.load(for: exerciseId)
        return entries.map { $0.date }
    }
    
    func saveOrReplaceAnalyticsEntry(
        exerciseId: UUID,
        setProgress: [SetProgress],
        date: Date
    ) {
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
        let calendar = Calendar.current
        if let idx = existingEntries.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            existingEntries[idx] = analyticsEntry
        } else {
            existingEntries.append(analyticsEntry)
        }
        storageService.save(existingEntries, for: exerciseId)
        print("Saved or replaced analytics entry for exercise \(exerciseId) on \(date)")
    }
}

extension AnalyticsViewModel {
    
    func trainingDaysInCurrentMonth(for exerciseId: UUID) -> Int {
        let dates = loadAnalyticsDates(for: exerciseId)
        let calendar = Calendar.current
        
        let monthDates = dates
            .filter { calendar.isDate($0, equalTo: Date(), toGranularity: .month) }
            .map { calendar.startOfDay(for: $0) }
        
        return Set(monthDates).count
    }

    func currentMonthName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "LLLL"
        return formatter.string(from: Date()).capitalized
    }
    
    func weightIncreasesInCurrentMonth(for exerciseId: UUID) -> Int {
        let calendar = Calendar.current
        let entries = loadAnalytics(for: exerciseId)
        
        // Ffilter current month
        let currentMonthEntries = entries
            .filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }
            .sorted(by: { $0.date < $1.date }) // chronologisch sortieren
        
        // Extract the average weight per day (first set of the day)
        let dailyWeights: [(date: Date, weight: Int)] = currentMonthEntries.compactMap { entry in
            guard let weight = entry.setProgress.first?.weight else { return nil }
            let day = calendar.startOfDay(for: entry.date)
            return (date: day, weight: weight)
        }
        
        // Group by date, select the highest value of the day (multiple entries per day possible)
        let maxWeightPerDay: [(date: Date, weight: Int)] = Dictionary(grouping: dailyWeights, by: { $0.date })
            .compactMap { (date, values) in
                let maxWeight = values.map(\.weight).max() ?? 0
                return (date, maxWeight)
            }
            .sorted(by: { $0.date < $1.date })

        // Count the real increases
        var increases = 0
        var lastWeight: Int? = nil
        
        for (_, weight) in maxWeightPerDay {
            if let previous = lastWeight {
                if weight > previous {
                    increases += 1
                }
            }
            lastWeight = weight
        }

        return increases
    }
}
