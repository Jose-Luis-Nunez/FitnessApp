import Foundation

public struct AnalyticsEntry: Identifiable, Codable, Sendable {
    public let id: UUID
    public let exerciseId: UUID
    public let date: Date
    public let setProgress: [SetProgress]

    public init(id: UUID = UUID(), exerciseId: UUID, date: Date, setProgress: [SetProgress]) {
        self.id = id
        self.exerciseId = exerciseId
        self.date = date
        self.setProgress = setProgress
    }
}
