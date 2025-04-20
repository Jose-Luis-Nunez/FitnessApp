import SwiftUI

struct EditTypeMetadata {
    let title: String
    let placeholder: String
    let keyboardType: UIKeyboardType
    let validate: (String) -> Bool
    let save: (_ value: String, _ viewModel: ExerciseCardViewModel) -> Void
}

extension EditType {
    var metadata: EditTypeMetadata {
        switch self {
        case .seatChip:
            return EditTypeMetadata(
                title: L10n.sheetTitleSeat,
                placeholder: L10n.sheetPlaceholderSeat,
                keyboardType: .numberPad,
                validate: { !$0.isEmpty },
                save: { value, vm in vm.updateSeat(value) }
            )
        case .weightChip:
            return EditTypeMetadata(
                title: L10n.sheetTitleWeight,
                placeholder: L10n.sheetPlaceholderWeight,
                keyboardType: .numberPad,
                validate: { Int($0) != nil },
                save: { value, vm in
                    if let val = Int(value) {
                        vm.updateWeight(val)
                    }
                }
            )
        case .setsChip:
            return EditTypeMetadata(
                title: L10n.sheetTitleSets,
                placeholder: L10n.sheetPlaceholderSets,
                keyboardType: .numberPad,
                validate: { Int($0) != nil },
                save: { value, vm in
                    if let val = Int(value) {
                        vm.updateSets(val)
                    }
                }
            )
        case .repsChip:
            return EditTypeMetadata(
                title: L10n.sheetTitleReps,
                placeholder: L10n.sheetPlaceholderReps,
                keyboardType: .numberPad,
                validate: { Int($0) != nil },
                save: { value, vm in
                    if let val = Int(value) {
                        vm.updateReps(val)
                    }
                }
            )
        }
    }
}
