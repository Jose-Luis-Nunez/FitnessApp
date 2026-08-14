import Foundation
import FitnessCore

extension AnalyticsViewModel {

    func getDailyRepsProgression(from history: [AnalyticsEntry]) -> [DailyProgression] {
        let calendar = Calendar.current
        let sortedEntries = history
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

    func totalRepsIncreases(from history: [AnalyticsEntry]) -> Int {
        let calendar = Calendar.current
        let entries = history
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

    func trainingSessionsUntilRepsIncrease(from history: [AnalyticsEntry]) -> Int {
        let entries = history
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

    func repsPhases(from history: [AnalyticsEntry], limit: Int = 3) -> [WeightPhase] {
        let calendar = Calendar.current
        let entries = history.sorted(by: { $0.date < $1.date })
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
            let setsReps = BilateralSetGrouping.setRepsLabel(
                forEntries: dayEntries.map(\.setProgress),
                reps: maxReps
            )
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
