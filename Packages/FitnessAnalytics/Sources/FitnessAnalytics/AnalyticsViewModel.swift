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

    @ObservationIgnored private let storageService: AnalyticsStoring
    @ObservationIgnored private let exerciseStorageService: ExerciseStoring
    @ObservationIgnored private let workoutStorageService: WorkoutStoring
    @ObservationIgnored private let saveAnalyticsUseCase: SaveAnalyticsUseCase
    @ObservationIgnored private let deleteAnalyticsSetUseCase: DeleteAnalyticsSetUseCase
    @ObservationIgnored private let saveOrReplaceAnalyticsUseCase: SaveOrReplaceAnalyticsUseCase

    nonisolated public init(
        storageService: AnalyticsStoring? = nil,
        exerciseStorage: ExerciseStoring? = nil,
        workoutStorage: WorkoutStoring? = nil,
        saveAnalyticsUseCase: SaveAnalyticsUseCase? = nil,
        deleteAnalyticsSetUseCase: DeleteAnalyticsSetUseCase? = nil,
        saveOrReplaceAnalyticsUseCase: SaveOrReplaceAnalyticsUseCase? = nil
    ) {
        self.storageService = storageService ?? Container.shared.analyticsStorage()
        self.exerciseStorageService = exerciseStorage ?? Container.shared.exerciseStorage()
        self.workoutStorageService = workoutStorage ?? Container.shared.workoutStorage()
        self.saveAnalyticsUseCase = saveAnalyticsUseCase ?? Container.shared.saveAnalyticsUseCase()
        self.deleteAnalyticsSetUseCase = deleteAnalyticsSetUseCase ?? Container.shared.deleteAnalyticsSetUseCase()
        self.saveOrReplaceAnalyticsUseCase = saveOrReplaceAnalyticsUseCase ?? Container.shared.saveOrReplaceAnalyticsUseCase()
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

    public func deleteLogicalSetFromEntry(
        exerciseId: UUID,
        entryId: UUID,
        logicalSetIndex: Int
    ) {
        deleteAnalyticsSetUseCase.execute(
            exerciseId: exerciseId,
            entryId: entryId,
            logicalSetIndex: logicalSetIndex
        )
        reloadEntries(for: exerciseId)
    }
    
    public func saveGoal(for exercise: inout Exercise, goalText: String) {
        if goalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            exercise.goal = nil
        } else if let goalValue = Double(goalText.replacingOccurrences(of: ",", with: ".")) {
            exercise.goal = goalValue
        }
        
        exerciseStorageService.updateExercise(exercise)
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
        
        // Sort all entries chronologically
        let sortedEntries = entries.sorted(by: { $0.date < $1.date })

        // Group by day and find the maximum weight per day
        let dailyMaxWeights: [(date: Date, weight: Double)] = Dictionary(grouping: sortedEntries, by: { calendar.startOfDay(for: $0.date) })
            .compactMap { (date, dayEntries) in
                let maxWeight = dayEntries.flatMap { $0.setProgress.map { $0.weight } }.max() ?? 0.0
                return maxWeight > 0 ? (date, maxWeight) : nil
            }
            .sorted(by: { $0.date < $1.date })
        
        guard dailyMaxWeights.count >= 3 else {
            return 0 // Not enough data for analysis
        }
        
        var patterns: [Int] = []
        var currentWeight = dailyMaxWeights[0].weight
        var sessionsAtCurrentWeight = 1
        
        // Analyze pattern: after how many sessions is the weight increased?
        for i in 1..<dailyMaxWeights.count {
            let (_, weight) = dailyMaxWeights[i]

            if weight > currentWeight {
                // Weight was increased
                patterns.append(sessionsAtCurrentWeight)
                currentWeight = weight
                sessionsAtCurrentWeight = 1
            } else {
                // Same weight
                sessionsAtCurrentWeight += 1
            }
        }

        // Find the most frequent pattern (mode)
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
            let bilateralGroups = dayEntries.compactMap {
                BilateralSetGrouping.groups(for: $0.setProgress)
            }

            if bilateralGroups.count == dayEntries.count {
                let allGroups = bilateralGroups.flatMap { $0 }
                let maxWeight = allGroups
                    .map { max($0.left.weight, $0.right.weight) }
                    .max() ?? 0
                let groupsAtWeight = allGroups.filter {
                    max($0.left.weight, $0.right.weight) == maxWeight
                }
                let minReps = groupsAtWeight
                    .flatMap { [$0.left.currentReps, $0.right.currentReps] }
                    .min() ?? 0
                let totalReps = allSets.reduce(0) { $0 + $1.currentReps }
                let setsReps = "\(groupsAtWeight.count)×\(minReps) / side"
                return DaySession(
                    date: day,
                    weight: maxWeight,
                    setsReps: setsReps,
                    totalReps: totalReps
                )
            }

            let maxWeight = allSets.map(\.weight).max() ?? 0
            let setsAtWeight = allSets.filter { $0.weight == maxWeight }
            let totalReps = setsAtWeight.reduce(0) { $0 + $1.currentReps }
            let minReps = setsAtWeight.map(\.currentReps).min() ?? 0
            let setsReps = "\(setsAtWeight.count)×\(minReps)"
            return DaySession(
                date: day,
                weight: maxWeight,
                setsReps: setsReps,
                totalReps: totalReps
            )
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
