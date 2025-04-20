import SwiftUI

enum FieldColumn {
    case left, right
}

enum EditType: String {
    case seatChip, weightChip, setsChip, repsChip
}

enum ActionType: String {
    case analyticsIcon, analyticsText, exerciseCardTitleText
}

enum InteractionField: Identifiable {
    case edit(EditType), action(ActionType)
    
    var id: String {
        switch self {
        case .edit(let type): return "edit_\(type.rawValue)"
        case .action(let action): return "action_\(action.rawValue)"
        }
    }
}

struct ChipStyle {
    let textValue: String
    let textSuffix: String?
    let backgroundColor: Color
    let labelColor: Color
    let labelFont: Font
    let size: AppChipSize
    let icon: ChipIcon?
    
    var displayText: String {
        textValue + (textSuffix ?? "")
    }
}

struct TextStyle {
    let text: String
    let textFontSize: Font
    let textColor: Color
}

struct IconStyle {
    let icon: ChipIcon
    let frame: CGSize?
    let offset: CGSize?
}

enum ExerciseFieldDisplay {
    case chip(ChipStyle)
    case text(TextStyle)
    case icon(IconStyle)
}

struct ExerciseFieldStyle {
    let display: ExerciseFieldDisplay
    let column: FieldColumn?
    let frameHeight: CGFloat?
}

enum ExerciseCardConfig {
    static func config(for field: InteractionField) -> ExerciseFieldStyle {
        switch field {
        case .edit(.repsChip):
            return ExerciseFieldStyle(
                display: .chip(
                    ChipStyle(
                        textValue: "",
                        textSuffix: "",
                        backgroundColor: AppStyle.Color.purpleGrey,
                        labelColor: AppStyle.Color.white,
                        labelFont: AppStyle.Font.regularChip,
                        size: .regular,
                        icon: ChipIcon(systemName: "arrow.triangle.2.circlepath", color: AppStyle.Color.green)
                    )
                ),
                column: .left,
                frameHeight: nil
            )
            
        case .edit(.setsChip):
            return ExerciseFieldStyle(
                display: .chip(
                    ChipStyle(
                        textValue: "",
                        textSuffix: "x",
                        backgroundColor: AppStyle.Color.purpleGrey,
                        labelColor: AppStyle.Color.white,
                        labelFont: AppStyle.Font.regularChip,
                        size: .regular,
                        icon: ChipIcon(systemName: "bolt.fill", color: AppStyle.Color.yellow)
                    )
                ),
                column: .left,
                frameHeight: nil
            )
            
        case .edit(.weightChip):
            return ExerciseFieldStyle(
                display: .chip(
                    ChipStyle(
                        textValue: "",
                        textSuffix: " kg",
                        backgroundColor: AppStyle.Color.purpleGrey,
                        labelColor: AppStyle.Color.white,
                        labelFont: AppStyle.Font.largeChip,
                        size: .large,
                        icon: nil
                    )
                ),
                column: .right,
                frameHeight: AppStyle.Dimensions.chipHeight * 2 + 42
            )
            
        case .edit(.seatChip):
            return ExerciseFieldStyle(
                display: .chip(
                    ChipStyle(
                        textValue: "",
                        textSuffix: "",
                        backgroundColor: AppStyle.Color.purple,
                        labelColor: AppStyle.Color.white,
                        labelFont: AppStyle.Font.regularChip,
                        size: .regular,
                        icon: ChipIcon(image: "chairSettings", color: AppStyle.Color.white)
                    )
                ),
                column: .right,
                frameHeight: nil
            )
            
        case .action(.analyticsIcon):
            return ExerciseFieldStyle(
                display: .icon(
                    IconStyle(
                        icon: ChipIcon(
                            image: "iconActivityIncrease",
                            color: AppStyle.Color.purpleDark,
                            size: .wide
                        ),
                        frame: CGSize(width: 52, height: 52),
                        offset: CGSize(width: 12, height: -12)
                    )
                ),
                column: .left,
                frameHeight: nil
            )
            
        case .action(.analyticsText):
            return ExerciseFieldStyle(
                display: .text(
                    TextStyle(
                        text: L10n.analyticsText,
                        textFontSize: AppStyle.Font.defaultFont,
                        textColor: AppStyle.Color.purpleLight
                    )
                ),
                column: .left,
                frameHeight: nil
            )
            
        case .action(.exerciseCardTitleText):
            return ExerciseFieldStyle(
                display: .text(
                    TextStyle(
                        text: L10n.analyticsText,
                        textFontSize: AppStyle.Font.cardHeadline,
                        textColor: AppStyle.Color.white
                    )
                ),
                column: .left,
                frameHeight: nil
            )
        }
    }
}
