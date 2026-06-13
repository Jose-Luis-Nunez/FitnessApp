import Foundation
import SwiftData
import FitnessCore

/// Persists a single friend record whose training data is captured as a
/// canonical JSON blob (`envelopeJSON`) conforming to `WorkoutShareEnvelope`.
///
/// Re-import replaces the blob in-place; no SwiftData relationships into the
/// main workout/exercise graph are created — friend data is intentionally
/// isolated so it can never leak into exercise-loading queries.
///
/// `@_spi(PersistenceUI)` follows ADR-0002: only `FitnessStorage` tests and
/// specific SPI-opt-in consumers may use this model directly.
@_spi(PersistenceUI)
@Model
public final class FriendModel {
    @_spi(PersistenceUI) @Attribute(.unique) public var id: UUID
    @_spi(PersistenceUI) public var name: String
    @_spi(PersistenceUI) public var addedAt: Date
    /// Canonical, pretty-printed JSON of the `WorkoutShareEnvelope` as pasted
    /// by the user (re-encoded with sortedKeys for stable diffs).
    @_spi(PersistenceUI) public var envelopeJSON: String
    /// Extracted at import time to avoid re-decoding the full blob just to
    /// render the friend's tile / comparison header.
    @_spi(PersistenceUI) public var workoutName: String

    public init(id: UUID, name: String, addedAt: Date, envelopeJSON: String, workoutName: String) {
        self.id = id
        self.name = name
        self.addedAt = addedAt
        self.envelopeJSON = envelopeJSON
        self.workoutName = workoutName
    }

    @_spi(PersistenceUI)
    public func toDomain() -> Friend {
        Friend(id: id, name: name, addedAt: addedAt, workoutName: workoutName)
    }
}
