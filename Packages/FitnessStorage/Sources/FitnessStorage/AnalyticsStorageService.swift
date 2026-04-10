import Foundation
import FitnessCore

@MainActor
public final class AnalyticsStorageService: AnalyticsStoring {
    private let fileManager: FileManager
    private let userId: String

    nonisolated public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let defaults = UserDefaults.standard
        if let storedUserId = defaults.string(forKey: "userId") {
            self.userId = storedUserId
        } else {
            let newUserId = UUID().uuidString
            defaults.set(newUserId, forKey: "userId")
            self.userId = newUserId
        }
    }

    private func fileURL(for exerciseId: UUID) -> URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent("analytics_\(exerciseId)_\(userId).json")
    }

    public func save(_ entries: [AnalyticsEntry], for exerciseId: UUID) {
        let fileURL = fileURL(for: exerciseId)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save analytics: \(error)")
        }
    }

    public func load(for exerciseId: UUID) -> [AnalyticsEntry] {
        let fileURL = fileURL(for: exerciseId)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("No analytics file found at \(fileURL.path)")
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let entries = try decoder.decode([AnalyticsEntry].self, from: data)
            return entries
        } catch {
            print("Failed to load analytics: \(error)")
            return []
        }
    }
}
