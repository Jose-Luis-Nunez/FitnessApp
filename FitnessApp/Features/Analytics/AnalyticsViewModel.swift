import Combine
import Foundation

typealias DailyProgression = (date: Date, value: Double)

class AnalyticsViewModel: ObservableObject {
    let analyticsDidUpdate = PassthroughSubject<UUID, Never>()

    private let storageService: AnalyticsStoring
    private let exerciseStorageService: ExerciseStorageService
    
    init(storageService: AnalyticsStoring = AnalyticsStorageService(), exerciseStorageService: ExerciseStorageService = ExerciseStorageService()) {
        self.storageService = storageService
        self.exerciseStorageService = exerciseStorageService
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

        DispatchQueue.main.async {
            self.objectWillChange.send()
            self.analyticsDidUpdate.send(exerciseId)
        }
    }
    
    func loadAnalytics(for exerciseId: UUID) -> [AnalyticsEntry] {
        let entries = storageService.load(for: exerciseId)
        return entries
    }
    
    func loadAnalytics(for exerciseId: UUID, on date: Date) -> [AnalyticsEntry] {
        let calendar = Calendar.current
        let entries = loadAnalytics(for: exerciseId)
        let filteredEntries = entries.filter { entry in
            calendar.isDate(entry.date, inSameDayAs: date)
        }
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
            self.analyticsDidUpdate.send(exerciseId)
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
        
        // If no analytics entries left, mark exercise as not completed in exercise storage
        if existingEntries.isEmpty {
            updateExerciseCompletionStatus(exerciseId: exerciseId, isCompleted: false)
        }
        
        DispatchQueue.main.async {
            self.objectWillChange.send()
            self.analyticsDidUpdate.send(exerciseId)
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
    
    func totalWeightIncreases(for exerciseId: UUID) -> Int {
        let calendar = Calendar.current
        let entries = loadAnalytics(for: exerciseId)
            .sorted(by: { $0.date < $1.date })
        
        let maxWeightPerDay: [(date: Date, weight: Double)] = Dictionary(grouping: entries, by: { calendar.startOfDay(for: $0.date) })
            .compactMap { (date, dayEntries) in
                let maxWeight = dayEntries.flatMap { $0.setProgress.map(\.weight) }.max() ?? 0.0
                return maxWeight > 0 ? (date, maxWeight) : nil
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
    
    private func updateExerciseCompletionStatus(exerciseId: UUID, isCompleted: Bool) {
        guard let currentWorkout = WorkoutStorageService.shared.currentWorkout else { 
            print("No current workout found")
            return 
        }
        
        // Load exercises from all categories to find the exercise
        for category in MuscleCategoryGroup.allCases {
            var exercises = exerciseStorageService.loadForWorkout(workoutId: currentWorkout.id, category: category)
            
            if let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseId }) {
                exercises[exerciseIndex].isCompleted = isCompleted
                exerciseStorageService.saveForWorkout(exercises, workoutId: currentWorkout.id, category: category)
                print("Updated exercise \(exerciseId) completion status to \(isCompleted)")
                return
            }
        }
        
        print("Exercise \(exerciseId) not found in any category")
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
    
    func getDailyWeightProgression(for exerciseId: UUID) -> [DailyProgression] {
        let calendar = Calendar.current
        let entries = loadAnalytics(for: exerciseId)
        
        let maxWeightPerDay: [DailyProgression] = Dictionary(grouping: entries, by: { calendar.startOfDay(for: $0.date) })
            .compactMap { (date, dayEntries) in
                let maxWeight = dayEntries.flatMap { $0.setProgress.map(\.weight) }.max() ?? 0.0
                return maxWeight > 0 ? (date: date, value: maxWeight) : nil
            }
            .sorted(by: { $0.date < $1.date })
        
        return maxWeightPerDay
    }
    
    func lastTrainingDate(for exerciseId: UUID) -> Date? {
        loadAnalytics(for: exerciseId)
            .max(by: { $0.date < $1.date })?
            .date
    }
    
    func weightPhases(for exerciseId: UUID, limit: Int = 3) -> [WeightPhase] {
        let calendar = Calendar.current
        let entries = loadAnalytics(for: exerciseId).sorted(by: { $0.date < $1.date })
        guard !entries.isEmpty else { return [] }
        
        struct DaySession {
            let date: Date
            let weight: Double
            let setsReps: String
            let totalReps: Int
        }
        
        let grouped = Dictionary(grouping: entries, by: { calendar.startOfDay(for: $0.date) })
        let daySessions: [DaySession] = grouped.compactMap { (day, dayEntries) in
            let allSets = dayEntries.flatMap { $0.setProgress }
            guard !allSets.isEmpty else { return nil }
            let maxWeight = allSets.map(\.weight).max() ?? 0
            let setsAtWeight = allSets.filter { $0.weight == maxWeight }
            let totalReps = setsAtWeight.reduce(0) { $0 + $1.currentReps }
            let minReps = setsAtWeight.map(\.currentReps).min() ?? 0
            let setsReps = "\(setsAtWeight.count)×\(minReps)"
            return DaySession(date: day, weight: maxWeight, setsReps: setsReps, totalReps: totalReps)
        }
        .sorted(by: { $0.date < $1.date })
        
        guard !daySessions.isEmpty else { return [] }
        
        struct RawPhase {
            let weight: Double
            let sessionCount: Int
            let start: DaySession
            let end: DaySession
        }
        
        var rawPhases: [RawPhase] = []
        var phaseStart = daySessions[0]
        var phaseEnd = daySessions[0]
        var sessionCount = 1
        
        for i in 1..<daySessions.count {
            let current = daySessions[i]
            if current.weight == phaseStart.weight {
                phaseEnd = current
                sessionCount += 1
            } else {
                rawPhases.append(RawPhase(weight: phaseStart.weight, sessionCount: sessionCount, start: phaseStart, end: phaseEnd))
                phaseStart = current
                phaseEnd = current
                sessionCount = 1
            }
        }
        rawPhases.append(RawPhase(weight: phaseStart.weight, sessionCount: sessionCount, start: phaseStart, end: phaseEnd))
        
        let phasesToReturn = Array(rawPhases.suffix(limit))
        var result: [WeightPhase] = []
        
        for (index, raw) in phasesToReturn.enumerated() {
            let days: Int
            let globalIndex = rawPhases.count - phasesToReturn.count + index
            if globalIndex + 1 < rawPhases.count {
                days = calendar.dateComponents([.day], from: raw.start.date, to: rawPhases[globalIndex + 1].start.date).day ?? 0
            } else {
                days = calendar.dateComponents([.day], from: raw.start.date, to: raw.end.date).day ?? 0
            }
            
            result.append(WeightPhase(
                weight: raw.weight,
                sessionCount: raw.sessionCount,
                durationDays: max(days, 1),
                startSetsReps: raw.start.setsReps,
                startDate: raw.start.date,
                endSetsReps: raw.end.setsReps,
                endDate: raw.end.date,
                hasImproved: raw.end.totalReps > raw.start.totalReps
            ))
        }
        
        return result
    }

    // MARK: - Reps-based analytics (for exercises without weight)

    func getDailyRepsProgression(for exerciseId: UUID) -> [DailyProgression] {
        let calendar = Calendar.current
        let sortedEntries = loadAnalytics(for: exerciseId)
            .sorted(by: { $0.date < $1.date })

        let dailyReps: [(date: Date, reps: Int)] = sortedEntries.compactMap { entry in
            let maxReps = entry.setProgress.map(\.currentReps).max()
            guard let reps = maxReps else { return nil }
            let day = calendar.startOfDay(for: entry.date)
            return (date: day, reps: reps)
        }

        let maxRepsPerDay: [DailyProgression] = Dictionary(grouping: dailyReps, by: { $0.date })
            .compactMap { (date, values) in
                let maxReps = values.map(\.reps).max() ?? 0
                return (date: date, value: Double(maxReps))
            }
            .sorted(by: { $0.date < $1.date })

        return maxRepsPerDay
    }

    func totalRepsIncreases(for exerciseId: UUID) -> Int {
        let calendar = Calendar.current
        let entries = loadAnalytics(for: exerciseId)
            .sorted(by: { $0.date < $1.date })

        let dailyReps: [(date: Date, reps: Int)] = entries.compactMap { entry in
            let maxReps = entry.setProgress.map(\.currentReps).max()
            guard let reps = maxReps else { return nil }
            let day = calendar.startOfDay(for: entry.date)
            return (date: day, reps: reps)
        }

        let maxRepsPerDay = Dictionary(grouping: dailyReps, by: { $0.date })
            .compactMap { (date, values) -> (Date, Int)? in
                let maxReps = values.map(\.reps).max() ?? 0
                return (date, maxReps)
            }
            .sorted(by: { $0.0 < $1.0 })

        var increases = 0
        var lastReps: Int? = nil

        for (_, reps) in maxRepsPerDay {
            if let previous = lastReps, reps > previous {
                increases += 1
            }
            lastReps = reps
        }

        return increases
    }

    func trainingSessionsUntilRepsIncrease(for exerciseId: UUID) -> Int {
        let entries = loadAnalytics(for: exerciseId)
        let calendar = Calendar.current

        let sortedEntries = entries.sorted(by: { $0.date < $1.date })

        let dailyMaxReps: [(date: Date, reps: Int)] = Dictionary(grouping: sortedEntries, by: { calendar.startOfDay(for: $0.date) })
            .compactMap { (date, dayEntries) in
                let maxReps = dayEntries.flatMap { $0.setProgress.map { $0.currentReps } }.max() ?? 0
                return maxReps > 0 ? (date, maxReps) : nil
            }
            .sorted(by: { $0.date < $1.date })

        guard dailyMaxReps.count >= 3 else { return 0 }

        var patterns: [Int] = []
        var currentReps = dailyMaxReps[0].reps
        var sessionsAtCurrentReps = 1

        for i in 1..<dailyMaxReps.count {
            let (_, reps) = dailyMaxReps[i]
            if reps > currentReps {
                patterns.append(sessionsAtCurrentReps)
                currentReps = reps
                sessionsAtCurrentReps = 1
            } else {
                sessionsAtCurrentReps += 1
            }
        }

        guard !patterns.isEmpty else { return 0 }

        let patternFrequency = Dictionary(grouping: patterns, by: { $0 })
            .mapValues { $0.count }

        return patternFrequency.max(by: { $0.value < $1.value })?.key ?? 0
    }

    func repsPhases(for exerciseId: UUID, limit: Int = 3) -> [WeightPhase] {
        let calendar = Calendar.current
        let entries = loadAnalytics(for: exerciseId).sorted(by: { $0.date < $1.date })
        guard !entries.isEmpty else { return [] }

        struct DaySession {
            let date: Date
            let maxReps: Int
            let setsReps: String
            let totalReps: Int
        }

        let grouped = Dictionary(grouping: entries, by: { calendar.startOfDay(for: $0.date) })
        let daySessions: [DaySession] = grouped.compactMap { (day, dayEntries) in
            let allSets = dayEntries.flatMap { $0.setProgress }
            guard !allSets.isEmpty else { return nil }
            let maxReps = allSets.map(\.currentReps).max() ?? 0
            let totalReps = allSets.reduce(0) { $0 + $1.currentReps }
            let setsReps = "\(allSets.count)×\(maxReps)"
            return DaySession(date: day, maxReps: maxReps, setsReps: setsReps, totalReps: totalReps)
        }
        .sorted(by: { $0.date < $1.date })

        guard !daySessions.isEmpty else { return [] }

        struct RawPhase {
            let maxReps: Int
            let sessionCount: Int
            let start: DaySession
            let end: DaySession
        }

        var rawPhases: [RawPhase] = []
        var phaseStart = daySessions[0]
        var phaseEnd = daySessions[0]
        var sessionCount = 1

        for i in 1..<daySessions.count {
            let current = daySessions[i]
            if current.maxReps == phaseStart.maxReps {
                phaseEnd = current
                sessionCount += 1
            } else {
                rawPhases.append(RawPhase(maxReps: phaseStart.maxReps, sessionCount: sessionCount, start: phaseStart, end: phaseEnd))
                phaseStart = current
                phaseEnd = current
                sessionCount = 1
            }
        }
        rawPhases.append(RawPhase(maxReps: phaseStart.maxReps, sessionCount: sessionCount, start: phaseStart, end: phaseEnd))

        let phasesToReturn = Array(rawPhases.suffix(limit))
        var result: [WeightPhase] = []

        for (index, raw) in phasesToReturn.enumerated() {
            let days: Int
            let globalIndex = rawPhases.count - phasesToReturn.count + index
            if globalIndex + 1 < rawPhases.count {
                days = calendar.dateComponents([.day], from: raw.start.date, to: rawPhases[globalIndex + 1].start.date).day ?? 0
            } else {
                days = calendar.dateComponents([.day], from: raw.start.date, to: raw.end.date).day ?? 0
            }

            result.append(WeightPhase(
                weight: 0,
                sessionCount: raw.sessionCount,
                durationDays: max(days, 1),
                startSetsReps: raw.start.setsReps,
                startDate: raw.start.date,
                endSetsReps: raw.end.setsReps,
                endDate: raw.end.date,
                hasImproved: raw.end.totalReps > raw.start.totalReps,
                maxReps: raw.maxReps
            ))
        }

        return result
    }
}
