import Foundation
import FitnessCore

@MainActor
public final class MockAnalyticsStorage: AnalyticsStoring {
    public private(set) var savedEntries: [UUID: [AnalyticsEntry]] = [:]

    public init() {}

    public func save(_ entries: [AnalyticsEntry], for exerciseId: UUID) {
        savedEntries[exerciseId] = entries
    }

    public func load(for exerciseId: UUID) -> [AnalyticsEntry] {
        savedEntries[exerciseId] ?? []
    }
}

@MainActor
public final class StubAnalyticsStorage: AnalyticsStoring {
    public init() {}

    public func save(_ entries: [AnalyticsEntry], for exerciseId: UUID) {}
    public func load(for exerciseId: UUID) -> [AnalyticsEntry] { [] }
}
