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
    @StateObject private var analyticsViewModel: AnalyticsViewModel
    
    init(group: MuscleCategoryGroup) {
        self.group = group
        let muscleCategoryViewModel = MuscleCategoryViewModel(group: group)
        _viewModel = StateObject(wrappedValue: muscleCategoryViewModel)
        _formViewModel = StateObject(wrappedValue: muscleCategoryViewModel.formViewModel)
        _activeSetViewModel = StateObject(wrappedValue: muscleCategoryViewModel.activeSetViewModel)
        _analyticsViewModel = StateObject(wrappedValue: AnalyticsViewModel())
    }
    
    private var bottomBarVM: BottomActionBarViewModel {
        BottomActionBarViewModel(
            isSetInProgress: viewModel.isSetInProgress,
            currentSet: viewModel.currentSet,
            currentExercise: viewModel.currentExercise,
            hasActiveExercise: viewModel.hasActiveExercise,
            exercises: viewModel.exercises,
            isLastSetCompleted: viewModel.isLastSetCompleted,
            quickDoneModeActive: activeSetViewModel.quickDoneModeActive
        )
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                List {
                    exerciseListSection
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(AppStyle.Color.backgroundColor)
                    
                    if let exercise = activeSetViewModel.currentExercise {
                        Section {
                            VStack(spacing: 16) {
                                ActiveSetView(
                                    sets: exercise.sets,
                                    exercise: exercise,
                                    setProgress: $activeSetViewModel.setProgress,
                                    viewModel: activeSetViewModel
                                )
                                .onAppear {
                                    print("ActiveSetView appeared, isSetInProgress: \(activeSetViewModel.isSetInProgress)")
                                    if activeSetViewModel.isSetInProgress {
                                        activeSetViewModel.startTimer()
                                        print("Timer started, timerSeconds: \(activeSetViewModel.timerSeconds)")
                                    }
                                }
                                
                                TimerView(viewModel: activeSetViewModel)
                                    .frame(maxWidth: UIScreen.main.bounds.width - 36, alignment: .center)
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(AppStyle.Color.backgroundColor)
                        .listRowSeparator(.hidden)
                    }
                }
                .frame(maxWidth: UIScreen.main.bounds.width - 36, alignment: .center)
                .listStyle(.plain)
                .listSectionSpacing(0)
                .scrollContentBackground(.hidden)
                .padding(.top, -2)
                .padding(.bottom, formViewModel.showForm ? 340 : (activeSetViewModel.isEditing ? 240 : (bottomBarVM.shouldShow ? 70 : 40)))
                
            }
            .background(AppStyle.Color.backgroundColor)
            
            if bottomBarVM.shouldShow {
                BottomActionBarView(
                    viewModel: bottomBarVM,
                    onStart: {
                        print("Start Training clicked")
                        print("Exercises: \(viewModel.exercises.map { "\($0.name) - isCompleted: \($0.isCompleted)" })")
                        if let activeExercise = viewModel.exercises.first(where: { !$0.isCompleted }) {
                            if viewModel.currentExercise == nil || viewModel.currentExercise?.isCompleted == true {
                                viewModel.startSet(for: activeExercise)
                                print("Started set for: \(activeExercise.name)")
                            } else {
                                viewModel.startNextSet()
                                print("Started next set")
                            }
                        } else {
                            print("No active exercise found")
                        }
                    },
                    onCompleteSet: {
                        viewModel.stopTimer()
                        viewModel.completeCurrentSet()
                        print("Completed set, isLastSetCompleted: \(viewModel.isLastSetCompleted)")
                    },
                    onQuickDone: {
                        print("QuickDone clicked")
                        if let activeExercise = viewModel.currentExercise ?? viewModel.exercises.first(where: { !$0.isCompleted }) {
                            activeSetViewModel.startQuickDone(for: activeExercise)
                            print("QuickDone started for: \(activeExercise.name)")
                        }
                    },
                    onReset: {
                        viewModel.stopTimer()
                        viewModel.showResetConfirmation = true
                        print("Reset triggered")
                    },
                    onEditLess: {
                        viewModel.stopTimer()
                        activeSetViewModel.startEditing(mode: SetEditingMode.less)
                        print("Edit Less triggered")
                    },
                    onEditMore: {
                        viewModel.stopTimer()
                        activeSetViewModel.startEditing(mode: SetEditingMode.more)
                        print("Edit More triggered")
                    },
                    onFinish: {
                        viewModel.stopTimer()
                        if activeSetViewModel.isLastSetCompleted, let exercise = activeSetViewModel.currentExercise {
                            var updatedExercise = exercise
                            updatedExercise.isCompleted = true
                            viewModel.updateExercise(updatedExercise)
                            viewModel.saveAnalytics()
                            print("Finished exercise: \(exercise.name)")
                        }
                        viewModel.finishExercise()
                        activeSetViewModel.finishExercise()
                        activeSetViewModel.quickDoneModeActive = false
                    },
                    onAddExercise: {
                        withAnimation {
                            formViewModel.loadExercise(nil as Exercise?)
                            formViewModel.toggleForm()
                            print("Add Exercise triggered")
                        }
                    }
                )
                .padding(.bottom, 40)
            }
            
            if activeSetViewModel.isEditing {
                ActiveSetEditPickerView(
                    title: activeSetViewModel.editMode == SetEditingMode.less ? "Verschlechtert" : "Verbessert",
                    selectedReps: $activeSetViewModel.repsInput,
                    selectedWeight: $activeSetViewModel.weightInput,
                    repsRange: 1...30,
                    weightRange: 0...180,
                    onSave: { newReps, newWeight in
                        viewModel.updateCurrentReps(newReps, newWeight)
                        activeSetViewModel.isEditing = false
                        print("Edit saved: \(newReps) reps, \(newWeight) kg")
                    },
                    onCancel: {
                        activeSetViewModel.isEditing = false
                        print("Edit cancelled")
                    },
                    saveDisabled: !activeSetViewModel.isInputValid
                )
                .frame(maxWidth: .infinity, maxHeight: 200, alignment: .bottom)
                .offset(y: -50)
                .shadow(radius: 5)
                .transition(.move(edge: .bottom))
            }
            
            if formViewModel.showForm {
                ExercisePickerView(
                    title: formViewModel.editingExercise != nil ? "Übung bearbeiten" : L10n.cardCreationTitle,
                    name: $formViewModel.name,
                    reps: $formViewModel.reps,
                    weight: $formViewModel.weight,
                    sets: $formViewModel.sets,
                    isPresented: $formViewModel.showForm,
                    onSave: {
                        if let exercise = formViewModel.createOrUpdateExercise() {
                            if formViewModel.editingExercise != nil {
                                viewModel.updateExercise(exercise)
                            } else {
                                viewModel.add(exercise, atTop: true)
                            }
                            print("Exercise saved: \(exercise.name)")
                        }
                    },
                    onCancel: {
                        formViewModel.clearForm()
                        print("Exercise creation cancelled")
                    },
                    saveDisabled: !formViewModel.isFormValid,
                    repsRange: 1...30,
                    weightRange: 0...180,
                    setsRange: 1...10,
                    viewModel: viewModel,
                    editingExercise: formViewModel.editingExercise
                )
                .frame(maxWidth: .infinity, maxHeight: 300, alignment: .bottom)
                .offset(y: -50)
                .shadow(radius: 5)
                .transition(.move(edge: .bottom))
            }
        }
        .toolbar(content: {
            ToolbarItem(placement: .principal) {
                Text(group.displayName)
                    .font(AppStyle.Font.navigationHeadline)
                    .foregroundColor(AppStyle.Color.white)
                    .accessibilityIdentifier(IDS.groupTitle)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    withAnimation {
                        formViewModel.loadExercise(nil as Exercise?)
                        formViewModel.toggleForm()
                        print("Add exercise button clicked")
                    }
                }) {
                    Image(systemName: formViewModel.showForm ? "minus" : "plus")
                }
                .accessibilityIdentifier(IDS.addExerciseButton)
            }
        })
        .onChange(of: activeSetViewModel.isEditing) { _, newValue in
            if !newValue {
                activeSetViewModel.resetEditingState()
                print("Editing state changed to: \(newValue)")
            }
        }
        .alert(isPresented: $viewModel.showResetConfirmation) {
            Alert(
                title: Text("Reset Progress"),
                message: Text("Do you want to reset all exercise progress? This will allow you to start the sets again."),
                primaryButton: .destructive(Text("Reset")) {
                    viewModel.resetProgress()
                    print("Reset confirmed")
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private var exerciseListSection: some View {
        let isActiveSetVisible = activeSetViewModel.currentExercise != nil
        
        if isActiveSetVisible {
            if let exercise = viewModel.currentExercise ?? viewModel.exercises.first(where: { !$0.isCompleted }) {
                return AnyView(
                    ExerciseCardView(
                        viewModel: ExerciseCardViewModel(exercise: exercise) { updated in
                            viewModel.updateExercise(updated)
                        },
                        onEdit: { exercise in
                            withAnimation {
                                formViewModel.loadExercise(exercise)
                                formViewModel.toggleForm()
                                print("Edit exercise triggered: \(exercise.name)")
                            }
                        },
                        isEditable: !(viewModel.isSetInProgress),
                        analyticsViewModel: analyticsViewModel,
                        onStart: { selectedExercise in
                            print("Individuelle Übung gestartet: \(selectedExercise.name)")
                            viewModel.startSet(for: selectedExercise)
                        },
                        onReset: { selectedExercise in
                            viewModel.resetExercise(selectedExercise)
                        }
                    )
                    .padding(.vertical, 6)
                    .transition(.move(edge: .top))
                    .listRowSeparator(.hidden)
                )
            } else {
                return AnyView(EmptyView())
            }
        } else {
            return AnyView(
                Group {
                    incompleteExercisesSection
                    completedExercisesSection
                }
            )
        }
    }
    
    private var incompleteExercisesSection: some View {
        let incompleteExercises = viewModel.exercises.filter { !$0.isCompleted }
        
        if incompleteExercises.isEmpty {
            return AnyView(EmptyView())
        } else {
            return AnyView(
                ForEach(incompleteExercises, id: \.id) { exercise in
                    ExerciseCardView(
                        viewModel: ExerciseCardViewModel(exercise: exercise) { updated in
                            viewModel.updateExercise(updated)
                        },
                        onEdit: { exercise in
                            withAnimation {
                                formViewModel.loadExercise(exercise)
                                formViewModel.toggleForm()
                                print("Edit exercise triggered: \(exercise.name)")
                            }
                        },
                        isEditable: true,
                        analyticsViewModel: analyticsViewModel,
                        onStart: { selectedExercise in
                            print("Individuelle Übung gestartet: \(selectedExercise.name)")
                            viewModel.startTimer()
                            viewModel.startSet(for: selectedExercise)
                        },
                        onReset: { selectedExercise in
                            viewModel.resetExercise(selectedExercise)
                        }
                    )
                    .padding(.vertical, 6)
                    .transition(.move(edge: .top))
                    .listRowSeparator(.hidden)
                }
            )
        }
    }
    
    private var completedExercisesSection: some View {
        let completedExercises = viewModel.exercises.filter { $0.isCompleted }
        
        if completedExercises.isEmpty {
            return AnyView(EmptyView())
        } else {
            return AnyView(
                ForEach(completedExercises, id: \.id) { exercise in
                    ExerciseCardView(
                        viewModel: ExerciseCardViewModel(exercise: exercise) { updated in
                            viewModel.updateExercise(updated)
                        },
                        onEdit: { exercise in
                            withAnimation {
                                formViewModel.loadExercise(exercise)
                                formViewModel.toggleForm()
                                print("Edit exercise triggered: \(exercise.name)")
                            }
                        },
                        isEditable: true,
                        analyticsViewModel: analyticsViewModel,
                        onStart: { selectedExercise in
                            print("Individuelle Übung gestartet: \(selectedExercise.name)")
                            viewModel.startTimer()
                            viewModel.startSet(for: selectedExercise)
                        },
                        onReset: { selectedExercise in
                            viewModel.resetExercise(selectedExercise)
                        }
                        
                    )
                    .padding(.vertical, 6)
                    .transition(.move(edge: .bottom))
                    .listRowSeparator(.hidden)
                }
            )
        }
    }
}

