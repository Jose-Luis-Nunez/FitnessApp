import Foundation

struct ExerciseFieldData: Identifiable {
    let field: InteractionField
    let value: Double

    var id: String {
        field.id
    }

    var prefilledValue: String {
        if value == floor(value) {
            return "\(Int(value))"
        } else {
            return String(value).replacingOccurrences(of: ".", with: ",")
        }
    }
}
