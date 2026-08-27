import Foundation
import FitnessCore

/// One training day reduced to the figures the analytics features compare.
///
/// Sessions are grouped by `startOfDay`, so several entries logged on the same
/// day form a single session — which is what "compared to the previous
/// training" means to a user.
///
/// This type carries only numbers plus the day's raw entries. Label strings stay
/// with their callers on purpose: the weight and reps features format
/// `setsReps` differently (inline bilateral branch vs.
/// `BilateralSetGrouping.setRepsLabel`), so folding the label in here would
/// force one of them to change its output.
struct DayTrainingSession {
    let date: Date
    /// The day's entries, kept so callers can derive their own labels.
    let entries: [AnalyticsEntry]
    /// True when *every* entry of the day resolves into bilateral groups. The
    /// weight figures below are group-based in that case and set-based otherwise.
    let isBilateral: Bool
    let maxWeight: Double
    /// Sets — or bilateral groups — performed at `maxWeight`.
    let countAtMaxWeight: Int
    /// Lowest rep count among the sets at `maxWeight`; both sides count
    /// individually in the bilateral case.
    let minRepsAtMaxWeight: Int
    /// Highest rep count of the day, regardless of weight.
    let maxReps: Int
    let totalRepsAllSets: Int
    let totalRepsAtMaxWeight: Int
}

extension DayTrainingSession {
    /// Reduces a history to one session per training day, oldest first. Days
    /// without any recorded set are dropped.
    static func sessions(
        from history: [AnalyticsEntry],
        calendar: Calendar = .current
    ) -> [DayTrainingSession] {
        Dictionary(grouping: history, by: { calendar.startOfDay(for: $0.date) })
            .compactMap { day, dayEntries -> DayTrainingSession? in
                let allSets = dayEntries.flatMap(\.setProgress)

                // A day with no recorded set is not a training day. Every
                // maximum below is taken from a collection this guard proves
                // non-empty, so a missing maximum is an invariant violation
                // rather than something to substitute a zero for — a silent
                // zero would render as a real "0 kg" session.
                guard let maxReps = allSets.map(\.currentReps).max() else { return nil }

                let totalRepsAllSets = allSets.reduce(0) { $0 + $1.currentReps }

                let bilateralGroups = dayEntries.compactMap {
                    BilateralSetGrouping.groups(for: $0.setProgress)
                }
                let isBilateral = bilateralGroups.count == dayEntries.count

                if isBilateral {
                    let allGroups = bilateralGroups.flatMap { $0 }
                    // `groups(for:)` never returns an empty array — it rejects
                    // empty input — so a bilateral day always has groups.
                    guard let maxWeight = allGroups
                        .map({ max($0.left.weight, $0.right.weight) })
                        .max()
                    else {
                        assertionFailure(
                            "bilateral day resolved to zero groups: \(day)"
                        )
                        return nil
                    }
                    let groupsAtWeight = allGroups.filter {
                        max($0.left.weight, $0.right.weight) == maxWeight
                    }
                    let repsAtWeight = groupsAtWeight
                        .flatMap { [$0.left.currentReps, $0.right.currentReps] }
                    guard let minRepsAtMaxWeight = repsAtWeight.min() else {
                        assertionFailure(
                            "no sets at the day's own maximum weight: \(day)"
                        )
                        return nil
                    }
                    return DayTrainingSession(
                        date: day,
                        entries: dayEntries,
                        isBilateral: true,
                        maxWeight: maxWeight,
                        countAtMaxWeight: groupsAtWeight.count,
                        minRepsAtMaxWeight: minRepsAtMaxWeight,
                        maxReps: maxReps,
                        totalRepsAllSets: totalRepsAllSets,
                        totalRepsAtMaxWeight: repsAtWeight.reduce(0, +)
                    )
                }

                guard let maxWeight = allSets.map(\.weight).max() else {
                    assertionFailure("non-empty sets yielded no maximum weight: \(day)")
                    return nil
                }
                let setsAtWeight = allSets.filter { $0.weight == maxWeight }
                guard let minRepsAtMaxWeight = setsAtWeight.map(\.currentReps).min() else {
                    assertionFailure("no sets at the day's own maximum weight: \(day)")
                    return nil
                }
                return DayTrainingSession(
                    date: day,
                    entries: dayEntries,
                    isBilateral: false,
                    maxWeight: maxWeight,
                    countAtMaxWeight: setsAtWeight.count,
                    minRepsAtMaxWeight: minRepsAtMaxWeight,
                    maxReps: maxReps,
                    totalRepsAllSets: totalRepsAllSets,
                    totalRepsAtMaxWeight: setsAtWeight.reduce(0) { $0 + $1.currentReps }
                )
            }
            .sorted { $0.date < $1.date }
    }

    /// `setsReps` label in the weight feature's format.
    var weightSetsRepsLabel: String {
        isBilateral
            ? "\(countAtMaxWeight)×\(minRepsAtMaxWeight) / side"
            : "\(countAtMaxWeight)×\(minRepsAtMaxWeight)"
    }

    /// `setsReps` label in the reps feature's format, which delegates the
    /// bilateral decision to `BilateralSetGrouping` instead of branching here.
    var repsSetsRepsLabel: String {
        BilateralSetGrouping.setRepsLabel(
            forEntries: entries.map(\.setProgress),
            reps: maxReps
        )
    }

    /// Total reps as the weight-phase feature counts them.
    ///
    /// The two branches disagree — bilateral days count every set, unilateral
    /// days only the sets at `maxWeight`. That asymmetry predates this type and
    /// feeds `WeightPhase.hasImproved`, so it is preserved verbatim rather than
    /// "fixed" as a side effect of extracting this reduction.
    var weightPhaseTotalReps: Int {
        isBilateral ? totalRepsAllSets : totalRepsAtMaxWeight
    }
}
