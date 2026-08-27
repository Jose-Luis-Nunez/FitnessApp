import Foundation
import Observation
import FitnessCore
import FitnessStorage
import FitnessUI
import Factory
import os

private let logger = Logger(subsystem: "FitnessAnalytics", category: "AnalyticsViewModel")

public typealias DailyProgression = (date: Date, value: Double)

public enum AnalyticsLoadOutcome<Value: Sendable>: Sendable {
    /// The read completed, including a valid empty optional or collection.
    case loaded(Value)
    /// The read failed. Callers must preserve their current presentation so a
    /// later user intent can retry instead of treating the failure as no data.
    case failed
}

public typealias AnalyticsHistoryAvailabilityOutcome = AnalyticsLoadOutcome<Bool>
public typealias LatestAnalyticsEntryLoadOutcome = AnalyticsLoadOutcome<AnalyticsEntry?>
public typealias SessionImprovementLoadOutcome = AnalyticsLoadOutcome<SessionImprovement?>

@Observable
@MainActor
public final class ExerciseAnalyticsCacheRevision {
    public private(set) var value: UInt64 = 0

    fileprivate func advance() {
        value &+= 1
    }
}

private final class WeakCacheRevision {
    weak var value: ExerciseAnalyticsCacheRevision?

    init(_ value: ExerciseAnalyticsCacheRevision) {
        self.value = value
    }
}

@Observable
@MainActor
public final class AnalyticsViewModel {
    private static let cacheLimit = 128

    private enum LatestEntryState {
        case notLoaded
        case loaded(AnalyticsEntry?)
    }

    private struct CachedExerciseAnalytics {
        var hasEntries: Bool?
        var latestEntry: LatestEntryState
        var history: [AnalyticsEntry]?
        let revision: ExerciseAnalyticsCacheRevision
    }

    @ObservationIgnored private let storageService: AnalyticsStoring
    @ObservationIgnored private let exerciseStorageService: ExerciseStoring
    @ObservationIgnored private let workoutStorageService: WorkoutStoring
    @ObservationIgnored private let saveAnalyticsUseCase: SaveAnalyticsUseCase
    @ObservationIgnored private let deleteAnalyticsSetUseCase: DeleteAnalyticsSetUseCase
    @ObservationIgnored private let saveOrReplaceAnalyticsUseCase: SaveOrReplaceAnalyticsUseCase
    @ObservationIgnored private var cacheByExerciseId: [UUID: CachedExerciseAnalytics] = [:]
    @ObservationIgnored private var cacheOrder: [UUID] = []
    @ObservationIgnored private var weakRevisionsByExerciseId: [UUID: WeakCacheRevision] = [:]
    @ObservationIgnored private var dirtyHistoryExerciseIds: Set<UUID> = []

    public init(
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

    @discardableResult
    public func reloadEntries(for exerciseId: UUID) -> Bool {
        do {
            let loaded = try storageService.loadHistory(for: exerciseId)
            storeHistory(loaded, for: exerciseId)
            return true
        } catch {
            markHistoryDirty(exerciseId)
            if var record = cacheByExerciseId[exerciseId] {
                record.latestEntry = .notLoaded
                cacheByExerciseId[exerciseId] = record
            }
            logger.error("Failed to reload analytics for exercise \(exerciseId): \(error)")
            return false
        }
    }

    /// Answers only whether the card may offer its Last run drill-down.
    /// Production storage performs an identifier-only query for this intent.
    public func loadAnalyticsHistoryAvailability(
        for exerciseId: UUID
    ) -> AnalyticsHistoryAvailabilityOutcome {
        if let cached = cachedAvailability(for: exerciseId) {
            touchCache(exerciseId)
            return .loaded(cached)
        }
        do {
            let hasEntries = try storageService.hasEntries(for: exerciseId)
            storeAvailability(hasEntries, for: exerciseId)
            return .loaded(hasEntries)
        } catch {
            logger.error("Failed to check analytics availability for exercise \(exerciseId): \(error)")
            return .failed
        }
    }

    /// Loads the payload for the Last run drill-down. A successful empty result
    /// is cached; a failure is not, so the next tap can retry.
    public func loadLatestEntry(for exerciseId: UUID) -> LatestAnalyticsEntryLoadOutcome {
        if let record = cacheByExerciseId[exerciseId] {
            if let history = record.history,
               !dirtyHistoryExerciseIds.contains(exerciseId) {
                touchCache(exerciseId)
                return .loaded(history.max { $0.date < $1.date })
            }
            if case let .loaded(entry) = record.latestEntry {
                touchCache(exerciseId)
                return .loaded(entry)
            }
        }
        do {
            let entry = try storageService.loadLatestEntry(for: exerciseId)
            storeLatestEntry(entry, for: exerciseId)
            return .loaded(entry)
        } catch {
            logger.error("Failed to load latest analytics for exercise \(exerciseId): \(error)")
            return .failed
        }
    }

    /// Compares the two most recent training days of one exercise.
    ///
    /// Unlike `loadCardPhases` this is safe to call from a collapsed card: it
    /// uses a bounded two-day read instead of the full history. A cached full
    /// history is reused when one happens to be present, but the bounded result
    /// is deliberately **not** written into the history cache — it is partial,
    /// and consumers of `history` expect the complete series.
    ///
    /// `.loaded(nil)` means "no comparable earlier session"; a read failure stays
    /// `.failed` so the card can keep retrying instead of caching an empty state.
    public func loadSessionImprovement(
        for exerciseId: UUID,
        hasWeight: Bool
    ) -> SessionImprovementLoadOutcome {
        let history: [AnalyticsEntry]
        if let record = cacheByExerciseId[exerciseId],
           let cached = record.history,
           !dirtyHistoryExerciseIds.contains(exerciseId) {
            touchCache(exerciseId)
            history = cached
        } else {
            do {
                history = try storageService.loadRecentEntries(
                    for: exerciseId,
                    dayLimit: 2
                )
            } catch {
                logger.error("Failed to load recent analytics for exercise \(exerciseId): \(error)")
                return .failed
            }
        }
        return .loaded(Self.improvement(from: history, hasWeight: hasWeight))
    }

    /// Pure derivation, kept static so it is trivially testable without a view
    /// model instance or storage double.
    static func improvement(
        from history: [AnalyticsEntry],
        hasWeight: Bool,
        calendar: Calendar = .current
    ) -> SessionImprovement? {
        let sessions = DayTrainingSession
            .sessions(from: history, calendar: calendar)
            .suffix(2)
        guard let current = sessions.last else { return nil }
        let previous = sessions.count > 1 ? sessions.first : nil

        // Reps at the working weight are the meaningful figure for a weighted
        // exercise; a bodyweight exercise has no working weight, so its best rep
        // count of the day is used instead.
        let reps = { (session: DayTrainingSession) in
            hasWeight ? session.minRepsAtMaxWeight : session.maxReps
        }

        let weightGain = previous.map { current.maxWeight - $0.maxWeight }
        let repsGain = previous.map { reps(current) - reps($0) }

        return SessionImprovement(
            weightGain: (weightGain ?? 0) > 0 ? weightGain : nil,
            currentWeight: current.maxWeight,
            repsGain: (repsGain ?? 0) > 0 ? repsGain : nil,
            currentReps: reps(current)
        )
    }

    /// The full history is loaded only after the coaching-tip drill-down.
    public func loadCardPhases(
        for exerciseId: UUID,
        hasWeight: Bool
    ) -> [WeightPhase] {
        let history = loadAnalytics(for: exerciseId)
        return hasWeight
            ? weightPhases(from: history)
            : repsPhases(from: history)
    }

    /// Publishes confirmed workout-log writes without eagerly reading their
    /// latest entries or complete histories. Historical back-dates are allowed,
    /// so an unknown latest entry deliberately remains unknown.
    func publishPersistedEntries(_ entries: [AnalyticsEntry]) {
        for (exerciseId, newEntries) in Dictionary(grouping: entries, by: \.exerciseId) {
            var record = cacheRecord(for: exerciseId)
            record.hasEntries = true
            if record.history != nil {
                dirtyHistoryExerciseIds.insert(exerciseId)
            }

            if let newestPersisted = newEntries.max(by: { $0.date < $1.date }) {
                switch record.latestEntry {
                case .loaded(nil):
                    record.latestEntry = .loaded(newestPersisted)
                case let .loaded(existing?) where newestPersisted.date >= existing.date:
                    record.latestEntry = .loaded(newestPersisted)
                case .loaded, .notLoaded:
                    break
                }
            }

            record.revision.advance()
            cacheByExerciseId[exerciseId] = record
            touchCache(exerciseId)
        }
        evictCacheIfNeeded()
    }
    
    public func resolveLatestExercise(_ exercise: Exercise) -> Exercise {
        let workoutId = workoutStorageService.currentWorkout?.id ?? UUID()
        let exercises = exerciseStorageService.loadForWorkout(workoutId: workoutId, category: exercise.category)
        return exercises.first(where: { $0.id == exercise.id }) ?? exercise
    }
    
    public func saveAnalytics(exerciseId: UUID, setProgress: [SetProgress], date: Date = Date()) {
        guard !setProgress.isEmpty else { return }
        saveAnalyticsUseCase.execute(exerciseId: exerciseId, setProgress: setProgress, date: date)
        refreshAvailabilityAfterUnconfirmedWrite(for: exerciseId)
    }
    
    public func loadAnalytics(for exerciseId: UUID) -> [AnalyticsEntry] {
        if let cached = cacheByExerciseId[exerciseId]?.history,
           !dirtyHistoryExerciseIds.contains(exerciseId) {
            touchCache(exerciseId)
            return cached
        }
        do {
            let loaded = try storageService.loadHistory(for: exerciseId)
            storeHistory(loaded, for: exerciseId)
            return loaded
        } catch {
            markHistoryDirty(exerciseId)
            logger.error("Failed to load analytics for exercise \(exerciseId): \(error)")
            return cacheByExerciseId[exerciseId]?.history ?? []
        }
    }

    /// Render-safe cache lookup. It never falls back to storage.
    public func cachedEntries(for exerciseId: UUID) -> [AnalyticsEntry]? {
        cacheByExerciseId[exerciseId]?.history
    }

    /// Stable, per-exercise observable. Cards retain this lightweight token so
    /// a write for another exercise cannot invalidate their SwiftUI subtree.
    public func revisionSource(for exerciseId: UUID) -> ExerciseAnalyticsCacheRevision {
        if let cached = cacheByExerciseId[exerciseId]?.revision {
            return cached
        }
        if let existing = weakRevisionsByExerciseId[exerciseId]?.value {
            return existing
        }
        let revision = ExerciseAnalyticsCacheRevision()
        weakRevisionsByExerciseId[exerciseId] = WeakCacheRevision(revision)
        return revision
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

    private func cachedAvailability(for exerciseId: UUID) -> Bool? {
        guard let record = cacheByExerciseId[exerciseId] else { return nil }
        if let hasEntries = record.hasEntries {
            return hasEntries
        }
        if case let .loaded(entry) = record.latestEntry {
            return entry != nil
        }
        if let history = record.history,
           !dirtyHistoryExerciseIds.contains(exerciseId) {
            return !history.isEmpty
        }
        return nil
    }

    private func cacheRecord(for exerciseId: UUID) -> CachedExerciseAnalytics {
        cacheByExerciseId[exerciseId] ?? CachedExerciseAnalytics(
            hasEntries: nil,
            latestEntry: .notLoaded,
            history: nil,
            revision: revisionSource(for: exerciseId)
        )
    }

    private func storeAvailability(_ hasEntries: Bool, for exerciseId: UUID) {
        var record = cacheRecord(for: exerciseId)
        let changed = record.hasEntries != hasEntries
        record.hasEntries = hasEntries
        if !hasEntries {
            record.latestEntry = .loaded(nil)
        }
        if changed {
            record.revision.advance()
        }
        cacheByExerciseId[exerciseId] = record
        touchCache(exerciseId)
        evictCacheIfNeeded()
    }

    private func storeLatestEntry(_ entry: AnalyticsEntry?, for exerciseId: UUID) {
        var record = cacheRecord(for: exerciseId)
        record.hasEntries = entry != nil
        record.latestEntry = .loaded(entry)
        record.revision.advance()
        cacheByExerciseId[exerciseId] = record
        touchCache(exerciseId)
        evictCacheIfNeeded()
    }

    private func storeHistory(_ history: [AnalyticsEntry], for exerciseId: UUID) {
        var record = cacheRecord(for: exerciseId)
        record.hasEntries = !history.isEmpty
        record.latestEntry = .loaded(history.max { $0.date < $1.date })
        record.history = history
        record.revision.advance()
        cacheByExerciseId[exerciseId] = record
        dirtyHistoryExerciseIds.remove(exerciseId)
        touchCache(exerciseId)
        evictCacheIfNeeded()
    }

    private func refreshAvailabilityAfterUnconfirmedWrite(for exerciseId: UUID) {
        var record = cacheRecord(for: exerciseId)
        record.latestEntry = .notLoaded
        if record.history != nil {
            dirtyHistoryExerciseIds.insert(exerciseId)
        }
        record.revision.advance()
        cacheByExerciseId[exerciseId] = record
        touchCache(exerciseId)
        evictCacheIfNeeded()

        do {
            storeAvailability(try storageService.hasEntries(for: exerciseId), for: exerciseId)
        } catch {
            logger.error("Failed to refresh analytics availability for exercise \(exerciseId): \(error)")
        }
    }

    private func markHistoryDirty(_ exerciseId: UUID) {
        if cacheByExerciseId[exerciseId]?.history != nil {
            dirtyHistoryExerciseIds.insert(exerciseId)
        }
    }

    private func touchCache(_ exerciseId: UUID) {
        guard cacheByExerciseId[exerciseId] != nil else { return }
        cacheOrder.removeAll { $0 == exerciseId }
        cacheOrder.append(exerciseId)
    }

    private func evictCacheIfNeeded() {
        while cacheOrder.count > Self.cacheLimit {
            let evicted = cacheOrder.removeFirst()
            cacheByExerciseId.removeValue(forKey: evicted)
            dirtyHistoryExerciseIds.remove(evicted)
        }
        weakRevisionsByExerciseId = weakRevisionsByExerciseId.filter {
            $0.value.value != nil
        }
    }
}

extension AnalyticsViewModel {
    
    func trainingDaysInCurrentMonth(from history: [AnalyticsEntry]) -> Int {
        AnalyticsDateHelper.daysInCurrentMonth(from: history.map(\.date))
    }

    func totalWeightIncreases(from history: [AnalyticsEntry]) -> Int {
        let calendar = Calendar.current
        let entries = history
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
    
    
    func trainingSessionsUntilWeightIncrease(from history: [AnalyticsEntry]) -> Int {
        let entries = history
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
    
    func getDailyWeightProgression(from history: [AnalyticsEntry]) -> [DailyProgression] {
        let calendar = Calendar.current
        let entries = history
        
        let maxWeightPerDay: [DailyProgression] = Dictionary(grouping: entries, by: { calendar.startOfDay(for: $0.date) })
            .compactMap { (date, dayEntries) in
                let maxWeight = dayEntries.flatMap { $0.setProgress.map(\.weight) }.max() ?? 0.0
                return maxWeight > 0 ? (date: date, value: maxWeight) : nil
            }
            .sorted(by: { $0.date < $1.date })
        
        return maxWeightPerDay
    }
    
    func weightPhases(from history: [AnalyticsEntry], limit: Int = 3) -> [WeightPhase] {
        let calendar = Calendar.current
        let entries = history.sorted(by: { $0.date < $1.date })
        guard !entries.isEmpty else { return [] }
        
        let daySessions = DayTrainingSession.sessions(from: entries, calendar: calendar)
        
        guard !daySessions.isEmpty else { return [] }
        
        struct RawPhase {
            let weight: Double
            let sessionCount: Int
            let start: DayTrainingSession
            let end: DayTrainingSession
        }
        
        var rawPhases: [RawPhase] = []
        var phaseStart = daySessions[0]
        var phaseEnd = daySessions[0]
        var sessionCount = 1
        
        for i in 1..<daySessions.count {
            let current = daySessions[i]
            if current.maxWeight == phaseStart.maxWeight {
                phaseEnd = current
                sessionCount += 1
            } else {
                rawPhases.append(RawPhase(weight: phaseStart.maxWeight, sessionCount: sessionCount, start: phaseStart, end: phaseEnd))
                phaseStart = current
                phaseEnd = current
                sessionCount = 1
            }
        }
        rawPhases.append(RawPhase(weight: phaseStart.maxWeight, sessionCount: sessionCount, start: phaseStart, end: phaseEnd))
        
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
                startSetsReps: raw.start.weightSetsRepsLabel,
                startDate: raw.start.date,
                endSetsReps: raw.end.weightSetsRepsLabel,
                endDate: raw.end.date,
                hasImproved: raw.end.weightPhaseTotalReps > raw.start.weightPhaseTotalReps
            ))
        }
        
        return result
    }

}
