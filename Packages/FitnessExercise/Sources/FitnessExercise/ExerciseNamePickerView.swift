import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import FitnessCore
import FitnessResources
import FitnessUI

public struct ExerciseNamePickerView: View {
    @Bindable public var formViewModel: ExerciseFormViewModel
    @Binding public var isPresented: Bool
    public let onSave: () -> Void
    public let onCancel: () -> Void
    public var viewModel: MuscleCategoryViewModel
    public let editingExercise: Exercise?

    @State private var validIconOptions: [String] = []
    #if canImport(UIKit)
    @State private var keyboard = KeyboardObserver()
    #endif

    private let textColor: Color = AppStyle.Color.white

    private var hideChrome: Bool {
        #if canImport(UIKit)
        keyboard.isVisible
        #else
        false
        #endif
    }

    private var showIconPicker: Bool {
        !hideChrome && validIconOptions.count > 1
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
            onCancel: onCancel,
            actions: {
                if !hideChrome {
                    ExercisePickerActionButtons(
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
                VStack(spacing: 8) {
                    Text(L10n.cardEditNameTitle)
                        .font(AppStyle.Font.sheetTitle)
                        .foregroundColor(textColor)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)

                    HStack {
                        if let exercise = editingExercise {
                            Button(action: {
                                viewModel.deleteExercise(exercise)
                                onCancel()
                                isPresented = false
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(AppStyle.Color.white)
                                    .imageScale(.large)
                            }
                        }
                        Spacer()
                    }
                }
                .padding(.bottom, AppStyle.Padding.sectionSpacing)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Category")
                        .font(AppStyle.Font.sheetSectionLabel)
                        .foregroundColor(textColor)

                    Text(formViewModel.selectedCategory.displayName)
                        .font(AppStyle.Font.tileValue)
                        .foregroundColor(AppStyle.Color.green)
                        .padding(.leading, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, AppStyle.Padding.card)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Name of Exercise")
                        .font(AppStyle.Font.sheetSectionLabel)
                        .foregroundColor(textColor)

                    ExercisePickerInputField(text: $formViewModel.name)
                }
                .padding(.bottom, 20)

                if showIconPicker {
                    Divider().padding(.top, 0)

                    IconPickerView(
                        selectedIcon: $formViewModel.selectedIconName,
                        icons: validIconOptions
                    )
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                }
            }
        )
        .onAppear {
            validIconOptions = formViewModel.selectedCategory.availableIcons.filter { name in
                guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
                #if canImport(UIKit)
                return UIImage(named: name) != nil
                #else
                return true
                #endif
            }
        }
    }
}
