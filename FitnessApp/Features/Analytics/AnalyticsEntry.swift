import Foundation

struct AnalyticsEntry: Identifiable, Codable {
    let id: UUID
    let exerciseId: UUID
    let date: Date
    let setProgress: [SetProgress]
    
    init(id: UUID = UUID(), exerciseId: UUID, date: Date, setProgress: [SetProgress]) {
        self.id = id
        self.exerciseId = exerciseId
        self.date = date
        self.setProgress = setProgress
    }
}
