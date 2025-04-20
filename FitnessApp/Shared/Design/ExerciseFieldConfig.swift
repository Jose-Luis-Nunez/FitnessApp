import SwiftUI

enum FieldColumn {
    case left
    case right
}

enum EditType: String {
    case seatChip, weightChip, setsChip, repsChip
}

enum ActionType: String {
    case analyticsIcon
    case analyticsChip
}

enum InteractionField: Identifiable {
    case edit(EditType)
    case action(ActionType)

    var id: String {
        switch self {
        case .edit(let type): return "edit_\(type.rawValue)"
        case .action(let action): return "action_\(action.rawValue)"
        }
    }
}

struct ExerciseFieldStyle {
    let type: InteractionField?
    let icon: ChipIcon?
    let backgroundColor: Color
    let textSuffix: String?
    let column: FieldColumn?
    let chipSize: AppChipSize
    let frameHeight: CGFloat?
}

enum ExerciseFieldConfig {
    static func config(for field: InteractionField) -> ExerciseFieldStyle {
        switch field {
        case .edit(.repsChip):
            return ExerciseFieldStyle(
                type: field,
                icon: ChipIcon(systemName: "arrow.triangle.2.circlepath", color: AppStyle.Color.green),
                backgroundColor: AppStyle.Color.purpleGrey,
                textSuffix: "",
                column: .left,
                chipSize: .regular,
                frameHeight: nil
            )
        case .edit(.setsChip):
            return ExerciseFieldStyle(
                type: field,
                icon: ChipIcon(systemName: "bolt.fill", color: AppStyle.Color.yellow),
                backgroundColor: AppStyle.Color.purpleGrey,
                textSuffix: "x",
                column: .left,
                chipSize: .regular,
                frameHeight: nil
            )
        case .edit(.weightChip):
            return ExerciseFieldStyle(
                type: field,
                icon: nil,
                backgroundColor: AppStyle.Color.purpleGrey,
                textSuffix: " kg",
                column: .right,
                chipSize: .large,
                frameHeight: AppStyle.Dimensions.chipHeight * 2 + 42
            )
        case .edit(.seatChip):
            return ExerciseFieldStyle(
                type: field,
                icon: ChipIcon(image: "chairIcon", color: AppStyle.Color.white),
                backgroundColor: AppStyle.Color.purple,
                textSuffix: "",
                column: .right,
                chipSize: .regular,
                frameHeight: nil
            )
        case .action(.analyticsIcon):
            return ExerciseFieldStyle(
                type: .action(.analyticsIcon),
                icon: ChipIcon(image: "iconActivityIncrease", color: AppStyle.Color.purpleDark),
                backgroundColor: AppStyle.Color.purpleLight,
                textSuffix: "",
                column: .left,
                chipSize: .regular,
                frameHeight: nil
            )
        case .action(.analyticsChip):
            return ExerciseFieldStyle(
                type: field,
                icon: nil,
                backgroundColor: AppStyle.Color.purpleLight,
                textSuffix: "",
                column: .left,
                chipSize: .wide,
                frameHeight: nil
            )
        }
    }
}
