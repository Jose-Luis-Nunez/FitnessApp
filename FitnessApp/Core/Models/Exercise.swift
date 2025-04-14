import Foundation

struct Exercise: Identifiable, Codable, Equatable {
    // MARK: - Properties
    let id: UUID
    let name: String
    private(set) var weight: Int
    private(set) var reps: Int
    private(set) var sets: Int
    private(set) var seatSetting: String?
    private(set) var isCompleted: Bool
    private(set) var currentReps: Int
    
    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        name: String,
        weight: Int,
        reps: Int,
        sets: Int,
        seatSetting: String? = nil,
        isCompleted: Bool = false,
        currentReps: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.weight = max(0, weight)
        self.reps = max(1, reps)
        self.sets = max(1, sets)
        self.seatSetting = seatSetting
        self.isCompleted = isCompleted
        self.currentReps = currentReps ?? reps
    }
}

// MARK: - Mutations
extension Exercise {
    func updating(
        weight: Int? = nil,
        reps: Int? = nil,
        sets: Int? = nil,
        seatSetting: String? = nil,
        isCompleted: Bool? = nil,
        currentReps: Int? = nil
    ) -> Exercise {
        Exercise(
            id: id,
            name: name,
            weight: weight ?? self.weight,
            reps: reps ?? self.reps,
            sets: sets ?? self.sets,
            seatSetting: seatSetting ?? self.seatSetting,
            isCompleted: isCompleted ?? self.isCompleted,
            currentReps: currentReps ?? self.currentReps
        )
    }
    
    func markCompleted() -> Exercise {
        updating(isCompleted: true)
    }
    
    func reset() -> Exercise {
        updating(
            isCompleted: false,
            currentReps: reps
        )
    }
    
    func updateCurrentReps(_ newReps: Int) -> Exercise {
        updating(currentReps: max(0, newReps))
    }
}

// MARK: - Validation
extension Exercise {
    enum ValidationError: LocalizedError {
        case invalidWeight
        case invalidReps
        case invalidSets
        
        var errorDescription: String? {
            switch self {
            case .invalidWeight: return "Weight must be 0 or greater"
            case .invalidReps: return "Repetitions must be greater than 0"
            case .invalidSets: return "Sets must be greater than 0"
            }
        }
    }
    
    static func validate(weight: Int, reps: Int, sets: Int) throws {
        if weight < 0 { throw ValidationError.invalidWeight }
        if reps < 1 { throw ValidationError.invalidReps }
        if sets < 1 { throw ValidationError.invalidSets }
    }
} 
