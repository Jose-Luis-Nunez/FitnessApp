import Foundation

struct Exercise: Identifiable, Codable,Equatable {
    let id: UUID
    let name: String
    var weight: Int
    var reps: Int
    var sets: Int
    var seatSetting: String?
    var isCompleted: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        weight: Int,
        reps: Int,
        sets: Int,
        seatSetting: String? = nil,
        isCompleted: Bool = false,
    ) {
        self.id = id
        self.name = name
        self.weight = weight
        self.reps = reps
        self.sets = sets
        self.seatSetting = seatSetting
        self.isCompleted = isCompleted
    }
    
    static func == (lhs: Exercise, rhs: Exercise) -> Bool {
        return lhs.id == rhs.id
    }
}
