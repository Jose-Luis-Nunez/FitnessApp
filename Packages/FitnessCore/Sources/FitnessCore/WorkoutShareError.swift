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
            return "Das ist kein gültiges Workout-JSON."
        case .unsupportedVersion:
            return "Dieses Workout wurde mit einer neueren App-Version exportiert."
        case .schemaMismatch:
            return "Workout-Daten sind unvollständig oder beschädigt."
        case .persistenceFailed:
            return "Speichern fehlgeschlagen. Bitte erneut versuchen."
        case .exportFailed:
            return "Export fehlgeschlagen. Bitte erneut versuchen."
        }
    }
}
