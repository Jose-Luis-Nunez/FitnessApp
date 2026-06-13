import Foundation
import os
import FitnessCore

/// Shared helper for writing `WorkoutShareEnvelope` JSON to the iOS tmp
/// directory as a `.fitnessworkout` file. Extracted from `WorkoutsViewModel`
/// so other features (e.g. `FitnessFriends`) can reuse the same write path
/// and filename-sanitisation logic without duplicating it.
public enum WorkoutShareFileWriter {

    private static let logger = Logger(subsystem: "FitnessWorkouts", category: "WorkoutShareFileWriter")

    /// Writes `json` to a tmp file named `<sanitized-name>.<fileExtension>`.
    /// Returns the URL on success, `nil` on any I/O failure. Callers must
    /// fall back to sharing the raw JSON string when `nil` is returned.
    public static func write(json: String, name: String, fileExtension: String = "fitnessworkout") -> URL? {
        let filename = sanitizeFilename(name)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(filename).\(fileExtension)")
        guard let data = json.data(using: .utf8) else {
            logger.error("UTF-8 encoding failed for workout '\(name, privacy: .public)'")
            return nil
        }
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            logger.error("File write failed for '\(name, privacy: .public)': \(error, privacy: .public)")
            return nil
        }
    }

    /// Removes filesystem-unsafe characters from a name so it can become a
    /// filename. Replaces each of `/ \ ? % * | " < > :` with `_`, collapses
    /// consecutive underscores, trims surrounding whitespace, and falls back
    /// to `"workout"` if the result is empty or consists solely of underscores.
    public static func sanitizeFilename(_ name: String) -> String {
        var result = name
        for ch in "/\\?%*|\"<>:" {
            result = result.replacingOccurrences(of: String(ch), with: "_")
        }
        result = result.replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.isEmpty || result.allSatisfy({ $0 == "_" }) {
            return "workout"
        }
        return result
    }
}
