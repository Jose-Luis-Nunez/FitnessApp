import Foundation

/// Lightweight domain value type representing a friend whose workout data
/// has been imported for comparison. Does NOT carry the full envelope —
/// callers that need exercise/analytics data fetch via `FriendStoring.loadEnvelope(for:)`.
public struct Friend: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let addedAt: Date
    /// Name of the workout included in the friend's imported snapshot; displayed
    /// in comparison headers without requiring a full envelope decode.
    public let workoutName: String

    public init(id: UUID, name: String, addedAt: Date, workoutName: String) {
        self.id = id
        self.name = name
        self.addedAt = addedAt
        self.workoutName = workoutName
    }
}
