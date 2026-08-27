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
    @Environment(\.appColorTheme) private var appColorTheme
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
            surface: .flat(AppStyle.Color.backgroundColor),
            expandsToTop: true,
            onCancel: onCancel,
            actions: {
                ExercisePickerActionButtons(
                    cancelLabel: AppText.actionCancel,
                    saveLabel: AppText.actionSave,
                    cancelColor: appColorTheme.accent.primary,
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
                ExerciseIconHeader(formViewModel: formViewModel, title: AppText.exerciseEditSeat)
                SeatSettingsEditor(formViewModel: formViewModel)
            }
        )
        .accessibilityIdentifier(ExerciseIDs.seatPicker)
    }
}
