import Foundation

struct ExerciseFieldData: Identifiable {
    let field: InteractionField
    let value: Int

    var id: String {
        field.id
    }

    var prefilledValue: String {
        "\(value)"
    }
}
