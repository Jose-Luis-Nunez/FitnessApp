import Foundation
@MainActor
public protocol FriendStoring: AnyObject {
    /// All currently stored friends, ordered by `addedAt` ascending.
    var friends: [Friend] { get }

    /// Upserts a friend by name (case-insensitive trimmed). If a friend with
    /// the same normalised name already exists, its `envelopeJSON` and
    /// `workoutName` are replaced (re-import = replace semantics).
    @discardableResult
    func upsertFriend(name: String, envelopeJSON: String, workoutName: String) throws -> Friend

    func deleteFriend(id: UUID)

    /// Decodes and returns the full `WorkoutShareEnvelope` for a given friend.
    func loadEnvelope(for friendId: UUID) throws -> WorkoutShareEnvelope
}
