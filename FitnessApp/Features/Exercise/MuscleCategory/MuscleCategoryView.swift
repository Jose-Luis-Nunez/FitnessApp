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
    
    private var bottomListPadding: CGFloat {
        if formViewModel.showForm { return 340 }
        if activeSetViewModel.isEditing { return 240 }
        if bottomActionbarViewModel.shouldShow { return safeAreaBottomInset + 100 }
        return safeAreaBottomInset + 40
    }

    private var safeAreaBottomInset: CGFloat {
        UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0
    }

    @EnvironmentObject private var overlayState: UIOverlayState

    var body: some View {
        ZStack(alignment: .bottom) {
            AppStyle.Color.backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer().frame(height: 16)
                ScrollView {
                    LazyVStack(spacing: 4) {
                        exerciseListSection
                            .padding(.horizontal, 0)

                        if let exercise = activeSetViewModel.currentExercise {
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
                            .padding(.vertical, 0)
                        }
                    }
                    .padding(.horizontal, 0)
                    .padding(.top, 0)
                    .padding(.bottom, bottomListPadding)
                }
                .offset(y: -10)
            }
            
            if bottomActionbarViewModel.shouldShow && !activeSetViewModel.isEditing {
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
                            formViewModel.loadExercise(nil, category: group)
                            formViewModel.toggleForm()
                        }
                    },
                    onResetAllExercises: {
                    }
                )
                .background(Color.clear)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 0)
                .padding(.bottom, safeAreaBottomInset + 12)
            }
            
            if activeSetViewModel.isEditing {
                // Signal: bring sheet to front, hide menu bar
                Color.clear
                    .onAppear { overlayState.isEditingSheetVisible = true }
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
                    weightOptions: generateWeightOptions(),
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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .shadow(radius: 5)
                .transition(.move(edge: .bottom))
                .zIndex(3)
                .ignoresSafeArea(edges: .bottom)
                .onDisappear { overlayState.isEditingSheetVisible = false }
            }
            
            if formViewModel.showForm {
                // Signal: bring sheet to front, hide menu bar
                Color.clear.onAppear { overlayState.isEditingSheetVisible = true }
                ExercisePickerView(
                    formViewModel: formViewModel,
                    title: formViewModel.editingExercise != nil ? L10n.cardEditTitle : L10n.cardCreationTitle,
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
                    weightOptions: generateWeightOptions(),
                    setsRange: 1...10,
                    viewModel: viewModel,
                    editingExercise: formViewModel.editingExercise,
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .shadow(radius: 5)
                .transition(.move(edge: .bottom))
                .zIndex(3)
                .ignoresSafeArea(edges: .bottom)
                .onDisappear { overlayState.isEditingSheetVisible = false }
            }
        }
        .customToolbar(title: group.displayName, navigationPath: $navigationPath, showBackButton: false)
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
        // Mini menu overlay extracted for compiler performance
        .overlay(miniMenuOverlay)
        .alert("Übungen zurücksetzen?", isPresented: $viewModel.showResetConfirmation) {
            Button("Zurücksetzen", role: .destructive) {
                viewModel.resetProgress()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Möchtest du wirklich alle Übungen in dieser Kategorie zurücksetzen?")
        }
    }
    
    private func updateBottomBarViewModel() {
        let _ = bottomActionbarViewModel
    }
    
    private func generateWeightOptions() -> [String] {
        var options: [String] = []
        for i in 0...180 {
            options.append(String(i))
            if i < 180 {
                let halfValue = Double(i) + 0.5
                options.append(String(halfValue).replacingOccurrences(of: ".", with: ","))
            }
        }
        return options
    }

    @ViewBuilder
    private func menuRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .foregroundColor(.white)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func menuSlot(icon: String, title: String, isVisible: Bool, action: @escaping () -> Void) -> some View {
        if isVisible {
            menuRow(icon: icon, title: title, action: action)
        } else {
            // Keep vertical rhythm even when item is not visible
            HStack { Spacer(minLength: 0) }
                .padding(.vertical, 10)
        }
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
                                formViewModel.loadExercise(exercise, category: group)
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
                                formViewModel.loadExercise(exercise, category: group)
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
                                formViewModel.loadExercise(exercise, category: group)
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
                    .listRowSeparator(.hidden)
                }
            )
        }
    }
    

}

// MARK: - Extracted overlays
private extension MuscleCategoryView {
    var miniMenuOverlay: some View {
        ZStack {
            if overlayState.showCategoryMiniMenu {
                // Backdrop to dismiss on outside tap
                Color.black.opacity(0.001)
                    .ignoresSafeArea(.all)
                    .onTapGesture { overlayState.showCategoryMiniMenu = false }

                // Floating menu panel
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        MiniActionMenuView(
                            title: nil,
                            items: [
                                // Top: New Exercise
                                MiniActionMenuItem(icon: viewModel.showNewExercise ? "plus" : nil, title: viewModel.showNewExercise ? "New Exercise" : "", isDestructive: false) {
                                    withAnimation {
                                        formViewModel.loadExercise(nil, category: group)
                                        formViewModel.toggleForm()
                                        overlayState.showCategoryMiniMenu = false
                                    }
                                },
                                // Middle: Start Training
                                MiniActionMenuItem(icon: viewModel.showStartTraining ? "play.fill" : nil, title: viewModel.showStartTraining ? "Start Training" : "", isDestructive: false) {
                                    if let exercise = activeSetViewModel.currentExercise ?? viewModel.exercises.first(where: { !$0.isCompleted }) {
                                        activeSetViewModel.startSet(for: exercise, category: group)
                                    }
                                    overlayState.showCategoryMiniMenu = false
                                },
                                // Bottom: Reset or Cancel
                                MiniActionMenuItem(icon: (viewModel.showCancel ? "xmark" : (viewModel.showReset ? "arrow.counterclockwise" : nil)), title: (viewModel.showCancel ? "Cancel" : (viewModel.showReset ? "Reset" : "")), isDestructive: false) {
                                    if viewModel.showCancel {
                                        activeSetViewModel.cancelActiveSet()
                                    } else if viewModel.showReset {
                                        viewModel.showResetConfirmation = true
                                    }
                                    overlayState.showCategoryMiniMenu = false
                                }
                            ],
                            width: min(UIScreen.main.bounds.width * 0.55, 320),
                            minHeight: 140
                        )
                        .padding(.trailing, 12)
                    }
            .padding(.bottom, safeAreaBottomInset - 50)
                }
                .transition(.opacity)
                .zIndex(4)
            }
        }
    }
}
