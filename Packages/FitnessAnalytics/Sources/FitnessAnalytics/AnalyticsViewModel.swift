import Foundation
import Observation
import FitnessCore
import FitnessStorage
import FitnessUI
import Factory

public typealias DailyProgression = (date: Date, value: Double)

@Observable
@MainActor
public final class AnalyticsViewModel {
    public private(set) var entries: [AnalyticsEntry] = []
    public private(set) var changeCount: Int = 0

    private let storageService: AnalyticsStoring
    @ObservationIgnored @Injected(\.exerciseStorage) private var exerciseStorageService
    @ObservationIgnored @Injected(\.workoutStorage) private var workoutStorageService
    @ObservationIgnored @Injected(\.saveAnalyticsUseCase) private var saveAnalyticsUseCase
    @ObservationIgnored @Injected(\.deleteAnalyticsSetUseCase) private var deleteAnalyticsSetUseCase
    @ObservationIgnored @Injected(\.saveOrReplaceAnalyticsUseCase) private var saveOrReplaceAnalyticsUseCase
    
    nonisolated public init(storageService: AnalyticsStoring? = nil) {
        self.storageService = storageService ?? Container.shared.analyticsStorage()
    }

    public func reloadEntries(for exerciseId: UUID) {
        entries = storageService.load(for: exerciseId)
        changeCount += 1
    }
    
    public func resolveLatestExercise(_ exercise: Exercise) -> Exercise {
        let workoutId = workoutStorageService.currentWorkout?.id ?? UUID()
        let exercises = exerciseStorageService.loadForWorkout(workoutId: workoutId, category: exercise.category)
        return exercises.first(where: { $0.id == exercise.id }) ?? exercise
    }
    
    public func saveAnalytics(exerciseId: UUID, setProgress: [SetProgress], date: Date = Date()) {
        guard !setProgress.isEmpty else { return }
        saveAnalyticsUseCase.execute(exerciseId: exerciseId, setProgress: setProgress, date: date)
        reloadEntries(for: exerciseId)
    }
    
    public func loadAnalytics(for exerciseId: UUID) -> [AnalyticsEntry] {
        storageService.load(for: exerciseId)
    }
    
    public func loadAnalytics(for exerciseId: UUID, on date: Date) -> [AnalyticsEntry] {
        let calendar = Calendar.current
        return loadAnalytics(for: exerciseId).filter { entry in
            calendar.isDate(entry.date, inSameDayAs: date)
        }
    }
    
    public func allDatesWithData(for exerciseId: UUID) -> Set<Date> {
        let entries = loadAnalytics(for: exerciseId)
        return AnalyticsDateHelper.uniqueDays(from: entries.map(\.date))
    }
    
    public func loadAnalyticsDates(for exerciseId: UUID) -> [Date] {
        storageService.load(for: exerciseId).map { $0.date }
    }
    
    public func saveOrReplaceAnalyticsEntry(
        exerciseId: UUID,
        setProgress: [SetProgress],
        date: Date
    ) {
        guard !setProgress.isEmpty else { return }
        saveOrReplaceAnalyticsUseCase.execute(exerciseId: exerciseId, setProgress: setProgress, date: date)
        reloadEntries(for: exerciseId)
    }
    
    public func deleteSetFromEntry(
        exerciseId: UUID,
        entryId: UUID,
        setIndex: Int
    ) {
        deleteAnalyticsSetUseCase.execute(exerciseId: exerciseId, entryId: entryId, setIndex: setIndex)
        reloadEntries(for: exerciseId)
    }
    
    public func saveGoal(for exercise: inout Exercise, goalText: String) {
        if goalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            exercise.goal = nil
        } else if let goalValue = Double(goalText.replacingOccurrences(of: ",", with: ".")) {
            exercise.goal = goalValue
        }
        
        let category = exercise.category
        let workoutId = workoutStorageService.currentWorkout?.id ?? UUID()
        var exercises = exerciseStorageService.loadForWorkout(workoutId: workoutId, category: category)
        
        if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            exercises[index] = exercise
            exerciseStorageService.saveForWorkout(exercises, workoutId: workoutId, category: category)
        }
    }
    
}

extension AnalyticsViewModel {
    
    public func trainingDaysInCurrentMonth(for exerciseId: UUID) -> Int {
        AnalyticsDateHelper.daysInCurrentMonth(from: loadAnalyticsDates(for: exerciseId))
    }

    public func currentMonthName() -> String {
        AnalyticsDateHelper.currentMonthName()
    }
    
    public func totalWeightIncreases(for exerciseId: UUID) -> Int {
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
    
    
    public func trainingSessionsUntilWeightIncrease(for exerciseId: UUID) -> Int {
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
    
    public func getDailyWeightProgression(for exerciseId: UUID) -> [DailyProgression] {
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
    
    public func lastTrainingDate(for exerciseId: UUID) -> Date? {
        loadAnalytics(for: exerciseId)
            .max(by: { $0.date < $1.date })?
            .date
    }
    
    public func weightPhases(for exerciseId: UUID, limit: Int = 3) -> [WeightPhase] {
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

}
