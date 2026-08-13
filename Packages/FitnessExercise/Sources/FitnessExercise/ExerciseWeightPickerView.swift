import SwiftUI
import FitnessResources
import FitnessUI

/// Standalone "Edit Exercise" sheet. Reuses step 1 of the create flow — the
/// body-icon header (titled with the exercise name instead of the category)
/// plus the set/reps/weight wheels and the bodyweight / decimal toggles
/// (`ExerciseIconHeader` + `ExerciseDetailsEditor`). The name input field is
/// intentionally omitted: this sheet edits an existing exercise's values, not
/// its name.
public struct ExerciseWeightPickerView: View {
    @Environment(\.appColorTheme) private var appColorTheme
    @Bindable public var formViewModel: ExerciseFormViewModel
    @Binding public var isPresented: Bool
    public let onSave: () -> Void
    public let onCancel: () -> Void
    public let repsRange: ClosedRange<Int>
    public let weightOptions: [String]
    public let setsRange: ClosedRange<Int>

    public init(
        formViewModel: ExerciseFormViewModel,
        isPresented: Binding<Bool>,
        onSave: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        repsRange: ClosedRange<Int>,
        weightOptions: [String],
        setsRange: ClosedRange<Int>
    ) {
        self.formViewModel = formViewModel
        _isPresented = isPresented
        self.onSave = onSave
        self.onCancel = onCancel
        self.repsRange = repsRange
        self.weightOptions = weightOptions
        self.setsRange = setsRange
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
                ExerciseIconHeader(formViewModel: formViewModel, title: formViewModel.name)
                ExerciseDetailsEditor(
                    formViewModel: formViewModel,
                    repsRange: repsRange,
                    weightOptions: weightOptions,
                    setsRange: setsRange,
                    editingExisting: formViewModel.editingExercise != nil
                )
            }
        )
    }
}
