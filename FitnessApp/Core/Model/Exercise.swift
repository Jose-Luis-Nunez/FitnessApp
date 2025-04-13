import Foundation

struct Exercise: Identifiable, Codable {
    let id: UUID
    var name: String
    var weight: Int
    var reps: Int
    var sets: Int
    var seatSetting: String?

    init(id: UUID = UUID(), name: String, weight: Int, reps: Int, sets: Int, seatSetting: String?) {
        self.id = id
        self.name = name
        self.weight = weight
        self.reps = reps
        self.sets = sets
        self.seatSetting = seatSetting
    }
}
