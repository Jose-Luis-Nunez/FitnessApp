import Foundation
import FitnessCore

/// A stretch of training reduced to the figures the analytics features compare.
///
/// Two granularities, one reduction. `sessions(from:calendar:)` groups by
/// `startOfDay`, which is what "compared to the previous training" means for the
/// completed card's improvement row. `workouts(from:)` keeps one session per
/// logged entry, which is what the increase features need — a day grouping keeps
/// only the day's maximum and so cannot see two workouts on one day where the
/// second was heavier.
///
/// This type carries only numbers plus the reduced raw entries. Label strings stay
/// with their callers on purpose: the weight and reps features format
/// `setsReps` differently (inline bilateral branch vs.
/// `BilateralSetGrouping.setRepsLabel`), so folding the label in here would
/// force one of them to change its output.
struct TrainingSession {
    let date: Date
    /// The reduced entries, kept so callers can derive their own labels.
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
    /// Highest rep count, regardless of weight.
    let maxReps: Int
    let totalRepsAtMaxWeight: Int
}

extension TrainingSession {
    /// Reduces a history to one session per training day, oldest first. Days
    /// without any recorded set are dropped.
    static func sessions(
        from history: [AnalyticsEntry],
        calendar: Calendar = .current
    ) -> [TrainingSession] {
        Dictionary(grouping: history, by: { calendar.startOfDay(for: $0.date) })
            .compactMap { day, dayEntries in reduced(date: day, entries: dayEntries) }
            .sorted { $0.date < $1.date }
    }

    /// One session per logged workout, oldest first.
    ///
    /// The increase features compare workouts rather than calendar days.
    /// Finishing an exercise twice in one day, the second time heavier, *is* an
    /// increase — but `sessions(from:calendar:)` keeps only the day's maximum, so
    /// the earlier, lighter workout disappears and with it the step up. That is
    /// also what the copy promises: "with N workouts", not "with N days".
    static func workouts(from history: [AnalyticsEntry]) -> [TrainingSession] {
        history
            .compactMap { reduced(date: $0.date, entries: [$0]) }
            .sorted { $0.date < $1.date }
    }

    /// The shared reduction. `entries` is a day's worth or a single workout's;
    /// every figure below is derived the same way either way.
    private static func reduced(
        date: Date,
        entries: [AnalyticsEntry]
    ) -> TrainingSession? {
        let allSets = entries.flatMap(\.setProgress)

        // A stretch with no recorded set is not training. Every
        // maximum below is taken from a collection this guard proves
        // non-empty, so a missing maximum is an invariant violation
        // rather than something to substitute a zero for — a silent
        // zero would render as a real "0 kg" session.
        guard let maxReps = allSets.map(\.currentReps).max() else { return nil }

        let bilateralGroups = entries.compactMap {
            BilateralSetGrouping.groups(for: $0.setProgress)
        }
        let isBilateral = bilateralGroups.count == entries.count

        if isBilateral {
            let allGroups = bilateralGroups.flatMap { $0 }
            // `groups(for:)` never returns an empty array — it rejects
            // empty input — so a bilateral session always has groups.
            guard let maxWeight = allGroups
                .map({ max($0.left.weight, $0.right.weight) })
                .max()
            else {
                assertionFailure(
                    "bilateral session resolved to zero groups: \(date)"
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
                    "no sets at this session's own maximum weight: \(date)"
                )
                return nil
            }
            return TrainingSession(
                date: date,
                entries: entries,
                isBilateral: true,
                maxWeight: maxWeight,
                countAtMaxWeight: groupsAtWeight.count,
                minRepsAtMaxWeight: minRepsAtMaxWeight,
                maxReps: maxReps,
                totalRepsAtMaxWeight: repsAtWeight.reduce(0, +)
            )
        }

        guard let maxWeight = allSets.map(\.weight).max() else {
            assertionFailure("non-empty sets yielded no maximum weight: \(date)")
            return nil
        }
        let setsAtWeight = allSets.filter { $0.weight == maxWeight }
        guard let minRepsAtMaxWeight = setsAtWeight.map(\.currentReps).min() else {
            assertionFailure("no sets at this session's own maximum weight: \(date)")
            return nil
        }
        return TrainingSession(
            date: date,
            entries: entries,
            isBilateral: false,
            maxWeight: maxWeight,
            countAtMaxWeight: setsAtWeight.count,
            minRepsAtMaxWeight: minRepsAtMaxWeight,
            maxReps: maxReps,
            totalRepsAtMaxWeight: setsAtWeight.reduce(0) { $0 + $1.currentReps }
        )
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
}
