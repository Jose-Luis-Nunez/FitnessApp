import Foundation

struct Exercise: Identifiable, Codable {
    let id: UUID
    var name: String
    var weight: Int
    var reps: Int
    var sets: Int
    var seatSetting: String?
    var isCompleted: Bool = false

    init(id: UUID = UUID(), name: String, weight: Int, reps: Int, sets: Int, seatSetting: String?, isCompleted: Bool = false) {
        self.id = id
        self.name = name
        self.weight = weight
        self.reps = reps
        self.sets = sets
        self.seatSetting = seatSetting
        self.isCompleted = isCompleted
    }
}
