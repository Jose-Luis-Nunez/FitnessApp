import Foundation

struct WeightPhase: Identifiable {
    let id = UUID()
    let weight: Double
    let sessionCount: Int
    let durationDays: Int
    let startSetsReps: String
    let startDate: Date
    let endSetsReps: String
    let endDate: Date
    let hasImproved: Bool
    let maxReps: Int?

    init(weight: Double, sessionCount: Int, durationDays: Int, startSetsReps: String, startDate: Date, endSetsReps: String, endDate: Date, hasImproved: Bool, maxReps: Int? = nil) {
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
