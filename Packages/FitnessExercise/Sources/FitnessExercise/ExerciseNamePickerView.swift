import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import FitnessCore
import FitnessResources
import FitnessUI

/// Standalone "Edit Title" sheet. Reuses step 1 of the create flow — the
/// body-icon header (titled with the category, with the icon chosen by swiping
/// the gallery) plus the name input field (`ExerciseIconHeader` +
/// `ExerciseNameBar`). The only thing unique to this screen is a trash button
/// to delete the exercise; the separate "Select icon" grid is gone (icons are
/// reachable by swiping the header gallery).
public struct ExerciseNamePickerView: View {
    @Environment(\.appColorTheme) private var appColorTheme
    @Bindable public var formViewModel: ExerciseFormViewModel
    @Binding public var isPresented: Bool
    public let onSave: () -> Void
    public let onCancel: () -> Void
    public var viewModel: MuscleCategoryViewModel
    public let editingExercise: Exercise?

    @FocusState private var isNameFocused: Bool
    #if canImport(UIKit)
    @State private var keyboard = KeyboardObserver()
    #endif

    private var hideChrome: Bool {
        #if canImport(UIKit)
        keyboard.isVisible
        #else
        false
        #endif
    }

    public init(
        formViewModel: ExerciseFormViewModel,
        isPresented: Binding<Bool>,
        onSave: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        viewModel: MuscleCategoryViewModel,
        editingExercise: Exercise?
    ) {
        self.formViewModel = formViewModel
        _isPresented = isPresented
        self.onSave = onSave
        self.onCancel = onCancel
        self.viewModel = viewModel
        self.editingExercise = editingExercise
    }

    public var body: some View {
        OverlaySheetContainer(
            isPresented: $isPresented,
            backgroundColor: AppStyle.Color.backgroundColor,
            expandsToTop: true,
            onCancel: onCancel,
            actions: {
                if !hideChrome {
                    ExercisePickerActionButtons(
                        cancelLabel: AppText.actionCancel,
                        saveLabel: AppText.actionSave,
                        cancelColor: appColorTheme.accent.primary,
                        saveDisabled: formViewModel.name.isEmpty,
                        onCancel: {
                            onCancel()
                            isPresented = false
                        },
                        onSave: {
                            onSave()
                            isPresented = false
                        }
                    )
                }
            },
            content: {
                ExerciseIconHeader(
                    formViewModel: formViewModel,
                    title: formViewModel.selectedCategory.localizedName
                )
                .overlay(alignment: .topLeading) {
                    if let exercise = editingExercise {
                        deleteButton(exercise)
                    }
                }

                ExerciseNameBar(text: $formViewModel.name, isFocused: $isNameFocused)
            }
        )
    }

    /// The one element unique to "Edit Title": delete the exercise and dismiss.
    private func deleteButton(_ exercise: Exercise) -> some View {
        Button {
            viewModel.deleteExercise(exercise)
            onCancel()
            isPresented = false
        } label: {
            Image(systemName: "trash")
                .font(AppStyle.Font.iconSymbol)
                .foregroundColor(AppStyle.Color.white)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
