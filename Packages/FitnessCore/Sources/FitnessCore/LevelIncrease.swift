import Foundation

/// The level a training session was performed at.
///
/// An enum rather than a weight plus an optional rep count, because exactly one
/// of the two applies and the consumer must not have to be told which by a
/// separate flag: a disagreement between the flag and the data used to render
/// "0 kg" on bodyweight exercises.
public enum TrainingLevel: Equatable {
    case weight(Double)
    case reps(Int)
}

/// One training day, reduced to what an increase tile needs to name it.
///
/// Bundled rather than spread across parallel fields on `LevelIncrease`: the three
/// values describe *one* session that actually happened, and separate fields
/// would let a later edit take the level from one day and the date from another
/// without anything complaining.
public struct LevelSession: Equatable {
    public let value: TrainingLevel
    public let setsReps: String
    public let date: Date

    public init(value: TrainingLevel, setsReps: String, date: Date) {
        self.value = value
        self.setsReps = setsReps
        self.date = date
    }
}

/// A step up: the session that first reached a new level, and the last session
/// at the level before it.
///
/// Only increases are modelled. A change of weight in either direction opens a
/// new grouping in the analytics history, but a deload is not progress, and a
/// tile that announced one would be stating the opposite of what happened.
///
/// `daysToReach` and `workoutsToReach` describe the *way to* this level — the
/// gap from `previousSession` to `startDate`, and the workouts spent at the old
/// level to earn it. They deliberately do not describe the time spent at the new
/// level; the tile's own two dates would contradict that.
public struct LevelIncrease: Identifiable {
    public let id = UUID()
    public let value: TrainingLevel
    public let daysToReach: Int
    public let workoutsToReach: Int
    public let startSetsReps: String
    public let startDate: Date
    public let previousSession: LevelSession

    public init(
        value: TrainingLevel,
        daysToReach: Int,
        workoutsToReach: Int,
        startSetsReps: String,
        startDate: Date,
        previousSession: LevelSession
    ) {
        self.value = value
        self.daysToReach = daysToReach
        self.workoutsToReach = workoutsToReach
        self.startSetsReps = startSetsReps
        self.startDate = startDate
        self.previousSession = previousSession
    }
}
