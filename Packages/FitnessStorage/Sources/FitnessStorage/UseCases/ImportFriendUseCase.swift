import Foundation
import os
import FitnessCore
import Factory

private let logger = Logger(subsystem: "FitnessStorage", category: "ImportFriendUseCase")

/// Validates and persists a friend's training data from a pasted JSON string.
///
/// Accepts the same `WorkoutShareEnvelope` format produced by `ExportWorkoutUseCase`.
/// On success, the friend's record is upserted by name (re-import replaces
/// existing data). Throws `WorkoutShareError` on any validation or persistence
/// failure — German error descriptions are already defined there.
@MainActor
public struct ImportFriendUseCase {
    private let friendStorage: FriendStoring

    public init(friendStorage: FriendStoring? = nil) {
        self.friendStorage = friendStorage ?? Container.shared.friendStorage()
    }

    /// - Parameters:
    ///   - friendName: Display name entered by the user. Must not be blank.
    ///   - jsonString: Raw JSON string from clipboard or paste field.
    /// - Returns: The persisted `Friend` domain value.
    @discardableResult
    public func execute(friendName: String, jsonString: String) throws -> Friend {
        let trimmedName = friendName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw WorkoutShareError.schemaMismatch(detail: "Friend name must not be empty.")
        }

        guard let data = jsonString.data(using: .utf8) else {
            throw WorkoutShareError.invalidJSON
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let envelope: WorkoutShareEnvelope
        do {
            envelope = try decoder.decode(WorkoutShareEnvelope.self, from: data)
        } catch let DecodingError.dataCorrupted(context) {
            logger.error("Friend import failed — dataCorrupted: \(context.debugDescription, privacy: .public)")
            throw WorkoutShareError.invalidJSON
        } catch let error as DecodingError {
            logger.error("Friend import failed — schema mismatch: \(String(describing: error), privacy: .public)")
            throw WorkoutShareError.schemaMismatch(detail: String(describing: error))
        } catch {
            logger.error("Friend import failed — decoder error: \(error, privacy: .public)")
            throw WorkoutShareError.invalidJSON
        }

        guard envelope.version >= 1 else {
            throw WorkoutShareError.unsupportedVersion(envelope.version)
        }
        guard envelope.version <= WorkoutShareEnvelope.currentVersion else {
            throw WorkoutShareError.unsupportedVersion(envelope.version)
        }

        // Re-encode canonically for stable storage (sorted keys, iso8601 dates).
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let canonicalData: Data
        do {
            canonicalData = try encoder.encode(envelope)
        } catch {
            logger.error("Friend import re-encode failed: \(error, privacy: .public)")
            throw WorkoutShareError.exportFailed
        }

        guard let canonicalJSON = String(data: canonicalData, encoding: .utf8) else {
            throw WorkoutShareError.exportFailed
        }

        do {
            return try friendStorage.upsertFriend(
                name: trimmedName,
                envelopeJSON: canonicalJSON,
                workoutName: envelope.workout.name
            )
        } catch {
            logger.error("Friend import persistence failed: \(error, privacy: .public)")
            throw WorkoutShareError.persistenceFailed
        }
    }
}
