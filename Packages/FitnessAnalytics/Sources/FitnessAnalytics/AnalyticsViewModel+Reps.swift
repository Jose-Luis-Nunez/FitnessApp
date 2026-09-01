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

        let daySessions = DayTrainingSession.sessions(from: entries, calendar: calendar)

        guard !daySessions.isEmpty else { return [] }

        struct RawPhase {
            let maxReps: Int
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

        // Same rule as the weighted path — only steps up, each paired with its
        // predecessor. See `weightPhases(from:limit:)`.
        var increases: [(phase: RawPhase, previous: RawPhase)] = []
        for index in 1..<rawPhases.count {
            let phase = rawPhases[index]
            let previous = rawPhases[index - 1]
            guard phase.maxReps > previous.maxReps else { continue }
            increases.append((phase, previous))
        }

        return increases.suffix(limit).map { entry in
            let days = calendar.dateComponents(
                [.day],
                from: entry.previous.end.date,
                to: entry.phase.start.date
            ).day ?? 0

            return WeightPhase(
                value: .reps(entry.phase.maxReps),
                daysToReach: max(days, 1),
                workoutsToReach: entry.previous.sessionCount,
                startSetsReps: entry.phase.start.repsSetsRepsLabel,
                startDate: entry.phase.start.date,
                previousSession: PhaseEndpoint(
                    value: .reps(entry.previous.maxReps),
                    setsReps: entry.previous.end.repsSetsRepsLabel,
                    date: entry.previous.end.date
                )
            )
        }
    }
}
