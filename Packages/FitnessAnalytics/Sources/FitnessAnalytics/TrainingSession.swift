import Foundation
import FitnessCore

/// One logged workout reduced to the figures the analytics features compare.
///
/// Deliberately per entry, not per calendar day. A day grouping keeps only the
/// day's maximum, so two workouts on one day where the second was heavier
/// collapse into a single session with nothing before it — which hid both the
/// increase from the coaching tiles and the gain from the completed card. The
/// day-grouped variant existed until the improvement row moved to this
/// granularity too and left it without a caller.
///
/// This type carries only numbers plus the reduced raw entries. Label strings stay
/// with their callers on purpose: the weight and reps features format
/// `setsReps` differently (inline bilateral branch vs.
/// `BilateralSetGrouping.setRepsLabel`), so folding the label in here would
/// force one of them to change its output.
struct TrainingSession {
    let date: Date
    /// The workout's entry, kept so callers can derive their own labels.
    let entries: [AnalyticsEntry]
    /// True when the workout's sets resolve into bilateral groups. The weight
    /// figures below are group-based in that case and set-based otherwise.
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
    /// One session per logged workout, oldest first. Entries without a recorded
    /// set are dropped.
    static func workouts(from history: [AnalyticsEntry]) -> [TrainingSession] {
        history
            .compactMap(reduced)
            .sorted { $0.date < $1.date }
    }

    /// Calendar days from one session to another, counted by day boundary.
    ///
    /// Both endpoints are normalised first. Sessions carry real timestamps, and
    /// `dateComponents([.day])` counts whole 24-hour units — an evening workout
    /// followed by a morning one two days later measures as one day, so a naive
    /// count under-reports by up to a full day. Shared by both increase builders
    /// so the correction cannot be present in one and missing in the other; a
    /// duplicated fix is a fix waiting to be half-reverted.
    static func daysBetween(
        _ earlier: TrainingSession,
        and later: TrainingSession,
        calendar: Calendar
    ) -> Int {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: earlier.date),
            to: calendar.startOfDay(for: later.date)
        ).day ?? 0
    }

    /// Reduces one logged workout to the figures the analytics features compare.
    private static func reduced(_ entry: AnalyticsEntry) -> TrainingSession? {
        let allSets = entry.setProgress

        // A stretch with no recorded set is not training. Every
        // maximum below is taken from a collection this guard proves
        // non-empty, so a missing maximum is an invariant violation
        // rather than something to substitute a zero for — a silent
        // zero would render as a real "0 kg" session.
        guard let maxReps = allSets.map(\.currentReps).max() else { return nil }

        if let allGroups = BilateralSetGrouping.groups(for: entry.setProgress) {
            // `groups(for:)` never returns an empty array — it rejects
            // empty input — so a bilateral session always has groups.
            guard let maxWeight = allGroups
                .map({ max($0.left.weight, $0.right.weight) })
                .max()
            else {
                assertionFailure(
                    "bilateral session resolved to zero groups: \(entry.date)"
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
                    "no sets at this session's own maximum weight: \(entry.date)"
                )
                return nil
            }
            return TrainingSession(
                date: entry.date,
                entries: [entry],
                isBilateral: true,
                maxWeight: maxWeight,
                countAtMaxWeight: groupsAtWeight.count,
                minRepsAtMaxWeight: minRepsAtMaxWeight,
                maxReps: maxReps,
                totalRepsAtMaxWeight: repsAtWeight.reduce(0, +)
            )
        }

        guard let maxWeight = allSets.map(\.weight).max() else {
            assertionFailure("non-empty sets yielded no maximum weight: \(entry.date)")
            return nil
        }
        let setsAtWeight = allSets.filter { $0.weight == maxWeight }
        guard let minRepsAtMaxWeight = setsAtWeight.map(\.currentReps).min() else {
            assertionFailure("no sets at this session's own maximum weight: \(entry.date)")
            return nil
        }
        return TrainingSession(
            date: entry.date,
            entries: [entry],
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
