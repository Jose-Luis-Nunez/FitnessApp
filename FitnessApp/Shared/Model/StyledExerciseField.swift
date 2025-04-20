import Foundation

struct StyledExerciseField: Identifiable {
    let data: ExerciseFieldData
    let style: ExerciseFieldStyle
    
    var id: String { data.id }
}

extension StyledExerciseField {
    init(field: InteractionField, value: Int = 0) {
        self.data = ExerciseFieldData(field: field, value: value)
        self.style = ExerciseCardConfig.config(for: field)
    }
}


extension StyledExerciseField {
    var fullText: String {
        "\(data.value)\((style.display.chip?.textSuffix ?? ""))"
    }
}

extension ExerciseFieldDisplay {
    var chip: ChipStyle? {
        if case let .chip(style) = self { return style }
        return nil
    }
}

extension ExerciseFieldDisplay {
    var text: TextStyle? {
        if case let .text(style) = self { return style }
        return nil
    }
}

extension ExerciseFieldDisplay {
    var icon: IconStyle? {
        if case let .icon(style) = self {
            return style
        }
        return nil
    }
}
