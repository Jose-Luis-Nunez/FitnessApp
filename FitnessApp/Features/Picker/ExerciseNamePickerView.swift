import SwiftUI
import UIKit

struct ExerciseNamePickerView: View {
    @ObservedObject var formViewModel: ExerciseFormViewModel
    @Binding var isPresented: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    let viewModel: MuscleCategoryViewModel
    let editingExercise: Exercise?

    @State private var isContentVisible: Bool = false
    @State private var validIconOptions: [String] = []

    private let textColor: Color = AppStyle.Color.white

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                    isPresented = false
                }

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 44, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                VStack(spacing: 8) {
                    Text(L10n.cardEditNameTitle)
                        .font(.title2)
                        .foregroundColor(textColor)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)

                    HStack {
                        if let exercise = editingExercise {
                            Button(action: {
                                if let index = viewModel.exercises.firstIndex(where: { $0.id == exercise.id }) {
                                    viewModel.exercises.remove(at: index)
                                    viewModel.saveExercises()
                                }
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
                    .padding(.horizontal, AppStyle.Padding.horizontal)
                }
                .padding(.bottom, 18)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Category")
                        .font(.headline)
                        .foregroundColor(textColor)

                    Text(formViewModel.selectedCategory.displayName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppStyle.Color.green)
                        .padding(.leading, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppStyle.Padding.horizontal)
                .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Name of Exercise")
                        .font(.headline)
                        .foregroundColor(textColor)

                    ExercisePickerInputField(text: $formViewModel.name)
                }
                .padding(.horizontal, AppStyle.Padding.horizontal)
                .padding(.bottom, 20)

                if validIconOptions.count > 1 {
                    Divider().padding(.top, 0)

                    IconPickerView(
                        selectedIcon: $formViewModel.selectedIconName,
                        icons: validIconOptions
                    )
                    .padding(.horizontal, AppStyle.Padding.horizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                }

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
            .exercisePickerSheet(isContentVisible: isContentVisible)
            .gesture(
                DragGesture().onEnded { value in
                    if value.translation.height > 80 {
                        onCancel()
                        isPresented = false
                    }
                }
            )
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            validIconOptions = formViewModel.selectedCategory.availableIcons.filter { name in
                guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
                return UIImage(named: name) != nil
            }
            withAnimation(.easeOut(duration: 0.18)) { isContentVisible = true }
        }
        .onChange(of: isPresented) { newValue in
            if !newValue { isContentVisible = false }
        }
    }
}
