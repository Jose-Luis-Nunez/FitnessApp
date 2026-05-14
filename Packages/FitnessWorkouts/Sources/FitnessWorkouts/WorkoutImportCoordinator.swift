import Foundation
import Observation
import os

private let logger = Logger(subsystem: "FitnessWorkouts", category: "WorkoutImportCoordinator")

/// Bridge between the App-level `.onOpenURL(_:)` handler and the WorkoutsScreen's
/// import-sheet. Registered as a Factory singleton so the App can write the
/// pending text *before* the WorkoutsScreen has mounted (cold-launch path).
/// When `pendingImportText` becomes non-nil, the screen observes the change and
/// presents the import sheet with that text prepopulated.
///
/// Lifetime: singleton across cold-launches. State is in-memory only — if the
/// app is killed before the user finishes the import, the pending text is lost
/// (acceptable: user can re-tap the source file).
@Observable
@MainActor
public final class WorkoutImportCoordinator {
    public var pendingImportText: String?

    public init() {}

    /// Reads the file at `url` and sets `pendingImportText` to its UTF-8 string.
    /// Called by the App-level `.onOpenURL` handler when a `.fitnessworkout`
    /// file (UTType `com.fitnesspro.workout-share`) is opened in another app
    /// (Files, Mail, Messages, AirDrop, Share-Sheet → "Open in FitnessApp").
    ///
    /// `startAccessingSecurityScopedResource()` is required when the URL comes
    /// from another app's sandbox (Files, Mail, Messages, AirDrop). Failure
    /// modes are silent no-ops — the import sheet simply does not open and the
    /// user can paste manually via the standard Import menu.
    public func handleIncomingFile(_ url: URL) {
        guard url.isFileURL else {
            logger.warning("Ignoring non-file URL: \(url.absoluteString, privacy: .public)")
            return
        }
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else {
            logger.error("Failed to read file: \(url.lastPathComponent, privacy: .public)")
            return
        }
        guard let text = String(data: data, encoding: .utf8) else {
            logger.error("Incoming file is not valid UTF-8: \(url.lastPathComponent, privacy: .public)")
            return
        }
        pendingImportText = text
    }

    /// Clears the pending text after the import sheet has consumed it.
    /// WorkoutsScreen must call this when it surfaces the sheet, so subsequent
    /// sheet openings (manual via menu) don't re-prefill with stale content.
    public func clearPending() {
        pendingImportText = nil
    }
}
