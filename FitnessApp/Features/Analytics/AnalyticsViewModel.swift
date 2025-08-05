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

        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    func deleteSetFromEntry(
        exerciseId: UUID,
        entryId: UUID,
        setIndex: Int
    ) {
        var existingEntries = storageService.load(for: exerciseId)
        
        guard let entryIndex = existingEntries.firstIndex(where: { $0.id == entryId }) else {
            print("Entry not found for deletion")
            return
        }
        
        let entry = existingEntries[entryIndex]
        guard setIndex < entry.setProgress.count else {
            print("Set index out of bounds")
            return
        }
        
        var updatedSetProgress = entry.setProgress
        updatedSetProgress.remove(at: setIndex)
        
        if updatedSetProgress.isEmpty {
            existingEntries.remove(at: entryIndex)
        } else {
            let updatedEntry = AnalyticsEntry(
                id: entry.id,
                exerciseId: entry.exerciseId,
                date: entry.date,
                setProgress: updatedSetProgress
            )
            existingEntries[entryIndex] = updatedEntry
        }
        
        storageService.save(existingEntries, for: exerciseId)
        
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    func updateSetInEntry(
        exerciseId: UUID,
        entryId: UUID,
        setIndex: Int,
        newSetProgress: SetProgress
    ) {
        var existingEntries = storageService.load(for: exerciseId)
        
        guard let entryIndex = existingEntries.firstIndex(where: { $0.id == entryId }) else {
            print("Entry not found for update")
            return
        }
        
        let entry = existingEntries[entryIndex]
        guard setIndex < entry.setProgress.count else {
            print("Set index out of bounds")
            return
        }
        
        var updatedSetProgress = entry.setProgress
        updatedSetProgress[setIndex] = newSetProgress
        
        let updatedEntry = AnalyticsEntry(
            id: entry.id,
            exerciseId: entry.exerciseId,
            date: entry.date,
            setProgress: updatedSetProgress
        )
        
        existingEntries[entryIndex] = updatedEntry
        storageService.save(existingEntries, for: exerciseId)
        
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
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
        
        let currentMonthEntries = entries
            .filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }
            .sorted(by: { $0.date < $1.date }) // chronologisch sortieren
        
        let dailyWeights: [(date: Date, weight: Double)] = currentMonthEntries.compactMap { entry in
            guard let weight = entry.setProgress.first?.weight else { return nil }
            let day = calendar.startOfDay(for: entry.date)
            return (date: day, weight: weight)
        }
        
        let maxWeightPerDay: [(date: Date, weight: Double)] = Dictionary(grouping: dailyWeights, by: { $0.date })
            .compactMap { (date, values) in
                let maxWeight = values.map(\.weight).max() ?? 0.0
                return (date, maxWeight)
            }
            .sorted(by: { $0.date < $1.date })
        
        var increases = 0
        var lastWeight: Double? = nil
        
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
    
    func trainingSessionsUntilWeightIncrease(for exerciseId: UUID) -> Int {
        let entries = loadAnalytics(for: exerciseId)
        let calendar = Calendar.current
        
        // Sortiere alle Einträge chronologisch
        let sortedEntries = entries.sorted(by: { $0.date < $1.date })
        
        // Gruppiere nach Tagen und finde das maximale Gewicht pro Tag
        let dailyMaxWeights: [(date: Date, weight: Double)] = Dictionary(grouping: sortedEntries, by: { calendar.startOfDay(for: $0.date) })
            .compactMap { (date, dayEntries) in
                let maxWeight = dayEntries.flatMap { $0.setProgress.map { $0.weight } }.max() ?? 0.0
                return maxWeight > 0 ? (date, maxWeight) : nil
            }
            .sorted(by: { $0.date < $1.date })
        
        guard dailyMaxWeights.count >= 3 else {
            return 0 // Nicht genug Daten für Analyse
        }
        
        var patterns: [Int] = []
        var currentWeight = dailyMaxWeights[0].weight
        var sessionsAtCurrentWeight = 1
        
        // Analysiere Pattern: Nach wie vielen Sessions wird das Gewicht erhöht?
        for i in 1..<dailyMaxWeights.count {
            let (_, weight) = dailyMaxWeights[i]
            
            if weight > currentWeight {
                // Gewicht wurde erhöht
                patterns.append(sessionsAtCurrentWeight)
                currentWeight = weight
                sessionsAtCurrentWeight = 1
            } else {
                // Gleiches Gewicht
                sessionsAtCurrentWeight += 1
            }
        }
        
        // Finde den häufigsten Pattern (Modus)
        guard !patterns.isEmpty else { return 0 }
        
        let patternFrequency = Dictionary(grouping: patterns, by: { $0 })
            .mapValues { $0.count }
        
        let mostCommonPattern = patternFrequency.max(by: { $0.value < $1.value })?.key ?? 0
        
        return mostCommonPattern
    }
}
