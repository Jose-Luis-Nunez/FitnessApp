import Foundation

struct StyledExerciseField: Identifiable {
    let data: ExerciseFieldData
    let style: ExerciseFieldStyle
    
    var id: String { data.id }
}
