import Foundation

/// How the most recent training day compares to the one before it, for a single
/// exercise.
///
/// Only *gains* are represented: a `nil` delta means "did not improve", which
/// covers an unchanged value, a decrease, and the case where there is no earlier
/// session to compare against. The completed card shows nothing for those, so
/// the distinction carries no meaning for its callers — and collapsing it here
/// keeps that decision out of the view.
public struct SessionImprovement: Equatable, Sendable {
    /// Weight gained since the previous training day, or `nil` if none.
    public let weightGain: Double?
    /// Heaviest weight of the most recent training day.
    public let currentWeight: Double
    /// Reps gained since the previous training day, or `nil` if none.
    public let repsGain: Int?
    /// Rep count reached on the most recent training day.
    public let currentReps: Int

    public init(
        weightGain: Double?,
        currentWeight: Double,
        repsGain: Int?,
        currentReps: Int
    ) {
        self.weightGain = weightGain
        self.currentWeight = currentWeight
        self.repsGain = repsGain
        self.currentReps = currentReps
    }

    /// True when neither metric improved — the card then falls back to a plain
    /// "Completed" label.
    public var isEmpty: Bool { weightGain == nil && repsGain == nil }
}
