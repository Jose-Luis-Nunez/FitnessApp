import Foundation

/// Portable transport format for a workout + its exercises + training history.
/// Serialized to JSON for sharing between devices via the iOS share sheet or
/// clipboard. Decoded on the receiving device to create a new workout with
/// fresh UUIDs.
///
/// Schema versioning: `version` MUST be checked on import. A receiver running
/// an older app version that doesn't understand a newer envelope version MUST
/// reject the import with `WorkoutShareError.unsupportedVersion`. Additive,
/// non-breaking fields (e.g. new optional Exercise properties) should NOT bump
/// the version — they should ride on `Codable`'s default-decoding tolerance.
/// Only breaking changes (renamed fields, removed required fields, restructured
/// nesting) require a version bump.
///
/// Note: `workout.isDefault` is NOT included here — that flag is per-device
/// metadata, not portable content.
public struct WorkoutShareEnvelope: Codable, Sendable {
    public static let currentVersion = 1

    public let version: Int
    public let exportedAt: Date
    public let app: String
    public let workout: Workout
    public let exercises: [Exercise]
    public let analytics: [AnalyticsEntry]

    public init(
        version: Int = WorkoutShareEnvelope.currentVersion,
        exportedAt: Date = Date(),
        app: String = "FitnessApp",
        workout: Workout,
        exercises: [Exercise],
        analytics: [AnalyticsEntry]
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.app = app
        self.workout = workout
        self.exercises = exercises
        self.analytics = analytics
    }
}
