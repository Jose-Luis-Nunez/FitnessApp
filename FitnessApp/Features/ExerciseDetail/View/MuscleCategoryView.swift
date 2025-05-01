import SwiftUI

private struct IDS {
    static let groupTitle = "id_title_group"
    static let nameField = "id_field_name"
    static let weightField = "id_field_weight"
    static let repsField = "id_field_reps"
    static let setsField = "id_field_sets"
    static let seatField = "id_field_seat"
    static let saveButton = "id_button_save"
    static let cancelButton = "id_button_cancel"
    static let addExerciseButton = "id_button_add_exercise"
}

struct MuscleCategoryView: View {
    let group: MuscleCategoryGroup
    @StateObject private var viewModel: MuscleCategoryViewModel
    @StateObject private var formViewModel: ExerciseFormViewModel
    @StateObject private var activeSetViewModel: ActiveSetViewModel

    init(group: MuscleCategoryGroup) {
        self.group = group
        let muscleCategoryViewModel = MuscleCategoryViewModel(group: group)
        _viewModel = StateObject(wrappedValue: muscleCategoryViewModel)
        _formViewModel = StateObject(wrappedValue: muscleCategoryViewModel.formViewModel)
        _activeSetViewModel = StateObject(wrappedValue: muscleCategoryViewModel.activeSetViewModel)
    }

    private var bottomBarVM: BottomActionBarViewModel {
        BottomActionBarViewModel(
            isSetInProgress: viewModel.isSetInProgress,
            currentSet: viewModel.currentSet,
            currentExercise: viewModel.currentExercise,
            hasActiveExercise: viewModel.hasActiveExercise,
            exercises: viewModel.exercises,
            isLastSetCompleted: viewModel.isLastSetCompleted
        )
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    List {
                        exerciseListSection
                            .listRowBackground(AppStyle.Color.backgroundColor)

                        if formViewModel.showForm {
                            exerciseFormSection
                                .listRowBackground(AppStyle.Color.backgroundColor)
                        }

                        if let exercise = viewModel.currentExercise {
                            Section {
                                ActiveSetView(
                                    sets: exercise.sets,
                                    exercise: exercise,
                                    setProgress: viewModel.setProgress,
                                    timerSeconds: viewModel.timerSeconds
                                )
                            }
                            .listRowBackground(AppStyle.Color.backgroundColor)
                        }
                    }
                    .listStyle(.plain)
                    .padding(.bottom, 80)
                    .scrollContentBackground(.hidden)
                }
                .background(AppStyle.Color.backgroundColor)

                if bottomBarVM.shouldShow {
                    BottomActionBarView(
                        viewModel: bottomBarVM,
                        onStart: {
                            viewModel.startTimer()
                            if let activeExercise = viewModel.exercises.first(where: { !$0.isCompleted }) {
                                if viewModel.currentExercise == nil {
                                    viewModel.startSet(for: activeExercise)
                                } else {
                                    viewModel.startNextSet()
                                }
                            }
                        },
                        onCompleteSet: {
                            viewModel.stopTimer()
                            viewModel.completeCurrentSet()
                        },
                        onReset: {
                            viewModel.stopTimer()
                            viewModel.showResetConfirmation = true
                        },
                        onEditLess: {
                            viewModel.stopTimer()
                            activeSetViewModel.startEditing(mode: SetEditingMode.less) // Anpassung an SetEditingMode
                        },
                        onEditMore: {
                            viewModel.stopTimer()
                            activeSetViewModel.startEditing(mode: SetEditingMode.more) // Anpassung an SetEditingMode
                        },
                        onFinish: {
                            viewModel.stopTimer()
                            viewModel.finishExercise()
                        },
                        onAddExercise: {
                            withAnimation { formViewModel.toggleForm() }
                        }
                    )
                }

                if activeSetViewModel.isEditing {
                    EditPickerView(
                        title: activeSetViewModel.editMode == SetEditingMode.less ? "Verschlechtert" : "Verbessert", // Anpassung an SetEditingMode
                        selectedReps: $activeSetViewModel.repsInput,
                        selectedWeight: $activeSetViewModel.weightInput,
                        repsRange: 1...30,
                        weightRange: 0...180,
                        onSave: { newReps, newWeight in
                            viewModel.updateCurrentReps(newReps, newWeight)
                            activeSetViewModel.isEditing = false
                        },
                        onCancel: {
                            activeSetViewModel.isEditing = false
                        },
                        saveDisabled: !activeSetViewModel.isInputValid
                    )
                    .frame(maxWidth: .infinity, maxHeight: 200, alignment: .bottom)
                    .shadow(radius: 5)
                    .transition(.move(edge: .bottom))
                    .ignoresSafeArea(edges: .bottom)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(group.displayName)
                    .font(AppStyle.Font.cardHeadline)
                    .foregroundColor(AppStyle.Color.white)
                    .accessibilityIdentifier(IDS.groupTitle)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    withAnimation { formViewModel.toggleForm() }
                }) {
                    Image(systemName: formViewModel.showForm ? "minus" : "plus")
                }
                .accessibilityIdentifier(IDS.addExerciseButton)
            }
        }
        .onChange(of: activeSetViewModel.isEditing) { _, newValue in
            if !newValue {
                activeSetViewModel.resetEditingState()
            }
        }
        .alert(isPresented: $viewModel.showResetConfirmation) {
            Alert(
                title: Text("Reset Progress"),
                message: Text("Do you want to reset all exercise progress? This will allow you to start the sets again."),
                primaryButton: .destructive(Text("Reset")) {
                    viewModel.resetProgress()
                },
                secondaryButton: .cancel()
            )
        }
        .onDisappear {
            viewModel.stopTimer()
        }
    }

    private var exerciseListSection: some View {
        Group {
            if viewModel.currentExercise != nil {
                if let currentExercise = viewModel.currentExercise {
                    ExerciseCardView(
                        viewModel: ExerciseCardViewModel(exercise: currentExercise) { updated in
                            viewModel.updateExercise(updated)
                        }
                    )
                    .padding(.vertical, 0.5)
                    .transition(.move(edge: .top))
                    .listRowSeparator(.hidden)
                }
            } else {
                ForEach(viewModel.exercises.filter { !$0.isCompleted }, id: \.id) { exercise in
                    ExerciseCardView(
                        viewModel: ExerciseCardViewModel(exercise: exercise) { updated in
                            viewModel.updateExercise(updated)
                        }
                    )
                    .padding(.vertical, 0.5)
                    .transition(.move(edge: .top))
                    .listRowSeparator(.hidden)
                }

                ForEach(viewModel.exercises.filter { $0.isCompleted }, id: \.id) { exercise in
                    ExerciseCardView(
                        viewModel: ExerciseCardViewModel(exercise: exercise) { updated in
                            viewModel.updateExercise(updated)
                        }
                    )
                    .padding(.vertical, 0.5)
                    .transition(.move(edge: .bottom))
                    .listRowSeparator(.hidden)
                }
            }
        }
        .animation(.easeInOut, value: viewModel.exercises.map { $0.isCompleted })
        .animation(.easeInOut, value: viewModel.currentExercise)
    }

    private var exerciseFormSection: some View {
        Section(header: Text(L10n.cardCreationTitle)) {
            TextField(L10n.cardCreationPlaceholderTextName, text: $formViewModel.name)
                .accessibilityIdentifier(IDS.nameField)
                .keyboardType(.default)

            TextField(L10n.cardCreationPlaceholderTextWeight, text: $formViewModel.weight)
                .accessibilityIdentifier(IDS.weightField)
                .keyboardType(.decimalPad)

            TextField(L10n.cardCreationPlaceholderTextRepetitions, text: $formViewModel.reps)
                .accessibilityIdentifier(IDS.repsField)
                .keyboardType(.numberPad)

            TextField(L10n.cardCreationPlaceholderTextSets, text: $formViewModel.sets)
                .accessibilityIdentifier(IDS.setsField)
                .keyboardType(.numberPad)

            TextField(L10n.cardCreationPlaceholderTextSeat, text: $formViewModel.seat)
                .accessibilityIdentifier(IDS.seatField)
                .keyboardType(.numberPad)

            HStack {
                Button(L10n.cardCreationSave) {
                    if let newExercise = formViewModel.createExercise() {
                        viewModel.add(newExercise)
                        formViewModel.clearForm()
                    }
                }
                .disabled(!formViewModel.isFormValid)
                .accessibilityIdentifier(IDS.saveButton)

                Spacer()

                Button(L10n.cardCreationCancel) {
                    formViewModel.clearForm()
                }
                .accessibilityIdentifier(IDS.cancelButton)
            }
            .padding(.top, 8)
        }
    }
}
