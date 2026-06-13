import Foundation

/// Errors surfaced by the workout share import pipeline. Each case maps to a
/// distinct user-facing message in the import sheet. Wrapped in `LocalizedError`
/// so SwiftUI alerts and error pills can pull the description directly.
public enum WorkoutShareError: LocalizedError, Equatable {
    /// Pasted text isn't valid JSON (parser threw, top-level decode failed).
    case invalidJSON
    /// Envelope `version` is higher than this app build understands.
    case unsupportedVersion(Int)
    /// Envelope is structurally valid JSON but misses a required field or has a
    /// type mismatch. `detail` is the underlying decoding error's debugDescription
    /// so logs carry the specific field; user message stays generic.
    case schemaMismatch(detail: String)
    /// Persistence layer rejected the import (SwiftData save failed). Rare.
    case persistenceFailed
    /// Export failed before reaching the share sheet — typically JSON encoding
    /// or aggregating exercises/analytics. User-facing only via the export
    /// alert; never surfaced inside the import sheet.
    case exportFailed

    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "That's not valid workout JSON."
        case .unsupportedVersion:
            return "This workout was exported with a newer app version."
        case .schemaMismatch:
            return "Workout data is incomplete or corrupted."
        case .persistenceFailed:
            return "Saving failed. Please try again."
        case .exportFailed:
            return "Export failed. Please try again."
        }
    }
}
