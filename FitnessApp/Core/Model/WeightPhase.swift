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
}
