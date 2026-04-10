import Foundation

@MainActor
public protocol AnalyticsStoring {
    func save(_ entries: [AnalyticsEntry], for exerciseId: UUID)
    func load(for exerciseId: UUID) -> [AnalyticsEntry]
}
