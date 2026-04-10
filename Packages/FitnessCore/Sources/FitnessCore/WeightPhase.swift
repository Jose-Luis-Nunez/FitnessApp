import Foundation

public struct WeightPhase: Identifiable {
    public let id = UUID()
    public let weight: Double
    public let sessionCount: Int
    public let durationDays: Int
    public let startSetsReps: String
    public let startDate: Date
    public let endSetsReps: String
    public let endDate: Date
    public let hasImproved: Bool
    public let maxReps: Int?

    public init(weight: Double, sessionCount: Int, durationDays: Int, startSetsReps: String, startDate: Date, endSetsReps: String, endDate: Date, hasImproved: Bool, maxReps: Int? = nil) {
        self.weight = weight
        self.sessionCount = sessionCount
        self.durationDays = durationDays
        self.startSetsReps = startSetsReps
        self.startDate = startDate
        self.endSetsReps = endSetsReps
        self.endDate = endDate
        self.hasImproved = hasImproved
        self.maxReps = maxReps
    }
}
