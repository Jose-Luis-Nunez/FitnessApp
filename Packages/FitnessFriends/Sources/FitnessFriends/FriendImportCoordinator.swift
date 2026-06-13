import Foundation
import Observation
import os

/// Singleton that bridges the App-level `.onOpenURL` handler (for `.fitnessfriend`
/// files) with `FriendsSection`. Must be a singleton so cold-launch URL deliveries
/// land in the same instance the view later observes.
@Observable
@MainActor
public final class FriendImportCoordinator {
    private static let logger = Logger(subsystem: "FitnessFriends", category: "FriendImportCoordinator")

    public var pendingImportJSON: String?
    public var pendingImportFileName: String?

    public init() {}

    public func handleIncomingFile(_ url: URL) {
        guard url.isFileURL else {
            Self.logger.warning("Ignoring non-file URL: \(url.absoluteString, privacy: .public)")
            return
        }
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else {
            Self.logger.error("Failed to read file: \(url.lastPathComponent, privacy: .public)")
            return
        }
        guard let text = String(data: data, encoding: .utf8) else {
            Self.logger.error("Incoming file is not valid UTF-8: \(url.lastPathComponent, privacy: .public)")
            return
        }
        pendingImportJSON = text
        pendingImportFileName = url.deletingPathExtension().lastPathComponent
    }

    public func clearPending() {
        pendingImportJSON = nil
        pendingImportFileName = nil
    }
}
