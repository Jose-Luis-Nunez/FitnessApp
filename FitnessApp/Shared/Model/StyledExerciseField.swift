import Foundation

struct StyledExerciseField: Identifiable {
    let data: ExerciseFieldData
    let style: ExerciseFieldStyle
    
    var id: String { data.id }
}

extension StyledExerciseField {
    var fullText: String {
        "\(data.value)\((style.display.chip?.textSuffix ?? ""))"
    }
}

private extension ExerciseFieldDisplay {
    var chip: ChipStyle? {
        if case let .chip(style) = self { return style }
        return nil
    }
}
