import SwiftUI

struct MuscleCategoryView: View {
    let group: MuscleCategoryGroup
    @StateObject private var viewModel: MuscleCategoryViewModel
    @StateObject private var formViewModel: ExerciseFormViewModel
    @StateObject private var activeSetViewModel: ActiveSetViewModel
    @StateObject private var analyticsViewModel: AnalyticsViewModel
    @Binding var navigationPath: NavigationPath
    
    init(group: MuscleCategoryGroup, navigationPath: Binding<NavigationPath>) {
        self.group = group
        let muscleCategoryViewModel = MuscleCategoryViewModel(group: group)
        _viewModel = StateObject(wrappedValue: muscleCategoryViewModel)
        _formViewModel = StateObject(wrappedValue: muscleCategoryViewModel.formViewModel)
        _activeSetViewModel = StateObject(wrappedValue: muscleCategoryViewModel.activeSetViewModel)
        _analyticsViewModel = StateObject(wrappedValue: AnalyticsViewModel())
        self._navigationPath = navigationPath
    }
    
    private var bottomActionbarViewModel: BottomActionBarViewModel {
        let vm = BottomActionBarViewModel(
            isSetInProgress: activeSetViewModel.isSetInProgress,
            currentSet: activeSetViewModel.currentSet,
            currentExercise: activeSetViewModel.currentExercise,
            hasActiveExercise: viewModel.hasActiveExercise,
            exercises: viewModel.exercises,
            isLastSetCompleted: activeSetViewModel.isLastSetCompleted,
            quickDoneModeActive: activeSetViewModel.quickDoneModeActive,
            quickDoneAllCompleted: activeSetViewModel.quickDoneAllCompleted,
            didEditCompleteSet: activeSetViewModel.didEditCompleteSet,
            didJustEditSet: activeSetViewModel.didJustEditSet,
            showResetAllExercisesButton: false
        )
      
        return vm
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color(AppStyle.Color.backgroundColor)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                List {
                    exerciseListSection
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
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
                                    if activeSetViewModel.isSetInProgress {
                                        activeSetViewModel.startTimer()
                                    }
                                }
                                
                                TimerView(viewModel: activeSetViewModel)
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(AppStyle.Color.backgroundColor)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .listSectionSpacing(0)
                .scrollContentBackground(.hidden)
                .padding(.top, 0)
                .offset(y: -10)
                .padding(.bottom, formViewModel.showForm ? 340 : (activeSetViewModel.isEditing ? 240 : (bottomActionbarViewModel.shouldShow ? 70 : 40)))
            }
            .background(AppStyle.Color.backgroundColor)
            
            if bottomActionbarViewModel.shouldShow {
                BottomActionBarView(
                    viewModel: bottomActionbarViewModel,
                    onStart: {
                        guard let exercise = activeSetViewModel.currentExercise ?? viewModel.exercises.first(where: { !$0.isCompleted }) else {
                            print("No valid exercise found for start")
                            return
                        }
                        if activeSetViewModel.currentSet == 0 && activeSetViewModel.setProgress.isEmpty {
                            activeSetViewModel.startSet(for: exercise, category: group)
                        } else {
                            activeSetViewModel.startNextSet()
                        }
                    },
                    onCompleteSet: {
                        activeSetViewModel.stopTimer()
                        activeSetViewModel.completeCurrentSet()
                    },
                    onQuickDone: {
                        if let activeExercise = activeSetViewModel.currentExercise ?? viewModel.exercises.first(where: { !$0.isCompleted }) {
                            activeSetViewModel.startQuickDone(for: activeExercise, category: group)
                        }
                    },
                    onCompleteAllQuickDone: {
                        activeSetViewModel.completeAllQuickDone()
                    },
                    onCategoryReset: {
                        activeSetViewModel.stopTimer()
                        viewModel.showResetConfirmation = true
                    },
                    onEditLess: {
                        activeSetViewModel.stopTimer()
                        activeSetViewModel.startEditingSet(index: activeSetViewModel.currentSet, mode: .less)
                    },
                    onEditMore: {
                        activeSetViewModel.stopTimer()
                        activeSetViewModel.startEditingSet(index: activeSetViewModel.currentSet, mode: .more)
                    },
                    onFinish: {
                        activeSetViewModel.stopTimer()
                        if activeSetViewModel.isLastSetCompleted,
                           let exercise = activeSetViewModel.currentExercise {
                            var updatedExercise = exercise
                            updatedExercise.isCompleted = true
                            viewModel.updateExercise(updatedExercise)
                            viewModel.saveAnalytics()
                        }
                        viewModel.finishExercise()
                        activeSetViewModel.finishExercise()
                        activeSetViewModel.quickDoneModeActive = false
                    },
                    onAddExercise: {
                        withAnimation {
                            formViewModel.loadExercise(nil as Exercise?)
                            formViewModel.toggleForm()
                        }
                    },
                    onResetAllExercises: {
                    }
                )
                .background(AppStyle.Color.backgroundColor)
                .padding(.bottom, 40)
            }
            
            if activeSetViewModel.isEditing {
                ActiveSetEditPickerView(
                    title: {
                        switch activeSetViewModel.editMode {
                        case .less: "Verschlechtert"
                        case .more: "Verbessert"
                        case .edit: "Bearbeiten"
                        }
                    }(),
                    selectedReps: $activeSetViewModel.repsInput,
                    selectedWeight: $activeSetViewModel.weightInput,
                    repsRange: 1...30,
                    weightRange: 0...180,
                    onSave: { newReps, newWeight in
                        activeSetViewModel.updateCurrentReps(newReps, newWeight)
                        activeSetViewModel.isEditing = false
                        activeSetViewModel.pendingEditIndex = nil
                    },
                    onCancel: {
                        activeSetViewModel.isEditing = false
                        activeSetViewModel.pendingEditIndex = nil
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
                    seat: $formViewModel.seat,
                    isPresented: $formViewModel.showForm,
                    onSave: {
                        if let exercise = formViewModel.createOrUpdateExercise() {
                            if formViewModel.editingExercise != nil {
                                viewModel.updateExercise(exercise)
                            } else {
                                viewModel.add(exercise, atTop: true)
                            }
                        }
                    },
                    onCancel: {
                        formViewModel.clearForm()
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
        .customToolbar(title: group.displayName, navigationPath: $navigationPath, showBackButton: true)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            updateBottomBarViewModel()
        }
        .onChange(of: activeSetViewModel.isSetInProgress) {
            updateBottomBarViewModel()
        }
        .onChange(of: activeSetViewModel.currentExercise) {
            updateBottomBarViewModel()
        }
        .alert("Übungen zurücksetzen?", isPresented: $viewModel.showResetConfirmation) {
            Button("Zurücksetzen", role: .destructive) {
                viewModel.resetProgress()
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Möchtest du wirklich alle Übungen in dieser Kategorie zurücksetzen?")
        }
    }
    
    private func updateBottomBarViewModel() {
        let _ = bottomActionbarViewModel
    }
    
    private var exerciseListSection: some View {
        let isActiveSetVisible = activeSetViewModel.currentExercise != nil
        
        if isActiveSetVisible {
            if let exercise = activeSetViewModel.currentExercise {
                return AnyView(
                    ExerciseCardContainerView(
                        viewModel: ExerciseCardViewModel(exercise: exercise) { updated in
                            viewModel.updateExercise(updated)
                        },
                        onEdit: { exercise in
                            withAnimation {
                                formViewModel.loadExercise(exercise)
                                formViewModel.toggleForm()
                            }
                        },
                        isEditable: !activeSetViewModel.isSetInProgress,
                        analyticsViewModel: analyticsViewModel,
                        activeSetViewModel: activeSetViewModel,
                        onStart: { selectedExercise in
                            activeSetViewModel.startSet(for: selectedExercise, category: group)
                        },
                        onReset: { selectedExercise in
                            viewModel.resetExercise(selectedExercise)
                        },
                        isActiveSetVisible: isActiveSetVisible,
                        isResetEnabled: exercise.isCompleted
                    )
                    .frame(maxWidth: .infinity)
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
                    ExerciseCardContainerView(
                        viewModel: ExerciseCardViewModel(exercise: exercise) { updated in
                            viewModel.updateExercise(updated)
                        },
                        onEdit: { exercise in
                            withAnimation {
                                formViewModel.loadExercise(exercise)
                                formViewModel.toggleForm()
                            }
                        },
                        isEditable: true,
                        analyticsViewModel: analyticsViewModel,
                        activeSetViewModel: activeSetViewModel,

                        onStart: { selectedExercise in
                            activeSetViewModel.startSet(for: selectedExercise, category: group)
                        },
                        onReset: { selectedExercise in
                            viewModel.resetExercise(selectedExercise)
                        },
                        isActiveSetVisible: activeSetViewModel.currentExercise != nil,
                        isResetEnabled: exercise.isCompleted
                    )
                    .frame(maxWidth: .infinity)
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
                    ExerciseCardContainerView(
                        viewModel: ExerciseCardViewModel(exercise: exercise) { updated in
                            viewModel.updateExercise(updated)
                        },
                        onEdit: { exercise in
                            withAnimation {
                                formViewModel.loadExercise(exercise)
                                formViewModel.toggleForm()
                            }
                        },
                        isEditable: true,
                        analyticsViewModel: analyticsViewModel,
                        activeSetViewModel: activeSetViewModel,

                        onStart: { selectedExercise in
                            activeSetViewModel.startSet(for: selectedExercise, category: group)
                        },
                        onReset: { selectedExercise in
                            viewModel.resetExercise(selectedExercise)
                        },
                        isActiveSetVisible: activeSetViewModel.currentExercise != nil,
                        isResetEnabled: exercise.isCompleted
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .transition(.move(edge: .bottom))
                    .listRowSeparator(.hidden)
                }
            )
        }
    }
}
