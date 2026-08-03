import SwiftUI
import FitnessCore
import FitnessResources
import FitnessUI

/// Standalone "Edit Seat" sheet. Reuses the exact step-2 layout of the create
/// flow (`ExerciseIconHeader` + `SeatSettingsEditor`) — the only differences
/// are the pre-filled values (loaded from the exercise via `formViewModel`),
/// the actual saved seat count, and the "Edit Seat" title instead of the
/// category name.
public struct ExerciseSeatPickerView: View {
    @Bindable public var formViewModel: ExerciseFormViewModel
    @Binding public var isPresented: Bool
    public let onSave: () -> Void
    public let onCancel: () -> Void

    public init(
        formViewModel: ExerciseFormViewModel,
        isPresented: Binding<Bool>,
        onSave: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.formViewModel = formViewModel
        _isPresented = isPresented
        self.onSave = onSave
        self.onCancel = onCancel
    }

    public var body: some View {
        OverlaySheetContainer(
            isPresented: $isPresented,
            backgroundColor: AppStyle.Color.backgroundColor,
            expandsToTop: true,
            onCancel: onCancel,
            actions: {
                ExercisePickerActionButtons(
                    cancelLabel: L10n.cardCreationCancel,
                    saveLabel: L10n.cardCreationSave,
                    cancelColor: AppStyle.Color.green,
                    saveDisabled: false,
                    onCancel: {
                        onCancel()
                        isPresented = false
                    },
                    onSave: {
                        onSave()
                        isPresented = false
                    }
                )
            },
            content: {
                ExerciseIconHeader(formViewModel: formViewModel, title: L10n.cardEditSeatTitle)
                SeatSettingsEditor(formViewModel: formViewModel)
            }
        )
        .accessibilityIdentifier(ExerciseIDs.seatPicker)
    }
}
