import SwiftUI

struct MuscleCategoryView: View {
    let group: MuscleCategoryGroup
    @StateObject private var viewModel: MuscleCategoryViewModel
    @StateObject private var formViewModel: ExerciseFormViewModel
    @StateObject private var trainingCoordinator: TrainingCoordinator
    @StateObject private var analyticsViewModel: AnalyticsViewModel
    @Binding var navigationPath: NavigationPath
    
    init(group: MuscleCategoryGroup, navigationPath: Binding<NavigationPath>) {
        self.group = group
        let muscleCategoryViewModel = MuscleCategoryViewModel(group: group)
        _viewModel = StateObject(wrappedValue: muscleCategoryViewModel)
        _formViewModel = StateObject(wrappedValue: muscleCategoryViewModel.formViewModel)
        _analyticsViewModel = StateObject(wrappedValue: AnalyticsViewModel())
        
        _trainingCoordinator = StateObject(wrappedValue: TrainingCoordinator(
            findCategory: { _ in group },
            onExerciseUpdate: { exercise, _ in
                muscleCategoryViewModel.updateExercise(exercise)
            },
            onExerciseReset: { exercise, _ in
                muscleCategoryViewModel.resetExercise(exercise)
            },
            onAddExercise: {
                withAnimation {
                    muscleCategoryViewModel.formViewModel.loadExercise(nil, category: group)
                    muscleCategoryViewModel.formViewModel.toggleForm()
                }
            },
            onResetAllExercises: {}
        ))
        self._navigationPath = navigationPath
    }
    
    private var bottomListPadding: CGFloat {
        if formViewModel.showForm { return 340 }
        if trainingCoordinator.activeSetViewModel.isEditing { return 240 }
        let actionBarViewModel = trainingCoordinator.createBottomActionBarViewModel(
            exercises: viewModel.exercises,
            hasActiveExercise: viewModel.hasActiveExercise
        )
        if actionBarViewModel.shouldShow { return safeAreaBottomInset + 100 }
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

                        TrainingSessionComponent(
                            coordinator: trainingCoordinator,
                            onEdit: { exercise in
                                withAnimation {
                                    formViewModel.loadExercise(exercise, category: group)
                                    formViewModel.toggleForm()
                                }
                            },
                            onReset: { exercise in
                                viewModel.resetExercise(exercise)
                            },
                            analyticsViewModel: analyticsViewModel
                        )
                    }
                    .padding(.horizontal, 0)
                    .padding(.top, 0)
                    .padding(.bottom, bottomListPadding)
                }
                .offset(y: -10)
            }
            
            TrainingActionBarComponent(
                coordinator: trainingCoordinator,
                exercises: viewModel.exercises,
                hasActiveExercise: viewModel.hasActiveExercise
            )
            .padding(.bottom, safeAreaBottomInset + 12)
            
            // Training Picker Component - Centralized picker logic
            TrainingPickerComponent(coordinator: trainingCoordinator)
            
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
                    weightOptions: WeightOptionsGenerator.generateExerciseWeightOptions(),
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
            // Refresh exercises when view appears (e.g., returning from TrainingView)
            viewModel.refreshExercises()
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
        let isActiveSetVisible = trainingCoordinator.currentExercise != nil
        
        if isActiveSetVisible {
            if let exercise = trainingCoordinator.currentExercise {
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
                        isEditable: !trainingCoordinator.activeSetViewModel.isSetInProgress,
                        analyticsViewModel: analyticsViewModel,
                        activeSetViewModel: trainingCoordinator.activeSetViewModel,
                        onStart: { selectedExercise in
                            // Navigate to TrainingView
                            TrainingNavigationHelper.navigateToTraining(
                                exercise: selectedExercise,
                                category: group,
                                navigationPath: &navigationPath
                            )
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
                        activeSetViewModel: trainingCoordinator.activeSetViewModel,

                        onStart: { selectedExercise in
                            // Navigate to TrainingView
                            TrainingNavigationHelper.navigateToTraining(
                                exercise: selectedExercise,
                                category: group,
                                navigationPath: &navigationPath
                            )
                        },
                        onReset: { selectedExercise in
                            viewModel.resetExercise(selectedExercise)
                        },
                        isActiveSetVisible: trainingCoordinator.currentExercise != nil,
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
                        activeSetViewModel: trainingCoordinator.activeSetViewModel,

                        onStart: { selectedExercise in
                            // Navigate to TrainingView
                            TrainingNavigationHelper.navigateToTraining(
                                exercise: selectedExercise,
                                category: group,
                                navigationPath: &navigationPath
                            )
                        },
                        onReset: { selectedExercise in
                            viewModel.resetExercise(selectedExercise)
                        },
                        isActiveSetVisible: trainingCoordinator.currentExercise != nil,
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
                                    if let exercise = trainingCoordinator.currentExercise ?? viewModel.exercises.first(where: { !$0.isCompleted }) {
                                        // Navigate to TrainingView
                                        TrainingNavigationHelper.navigateToTraining(
                                            exercise: exercise,
                                            category: group,
                                            navigationPath: &navigationPath
                                        )
                                    }
                                    overlayState.showCategoryMiniMenu = false
                                },
                                // Bottom: Reset or Cancel
                                MiniActionMenuItem(icon: (viewModel.showCancel ? "xmark" : (viewModel.showReset ? "arrow.counterclockwise" : nil)), title: (viewModel.showCancel ? "Cancel" : (viewModel.showReset ? "Reset" : "")), isDestructive: false) {
                                    if viewModel.showCancel {
                                        print("🔴 CANCEL CLICKED IN CATEGORYVIEW!")
                                        
                                        trainingCoordinator.activeSetViewModel.cancelActiveSet()
                                        
                                        // EINFACH: Cancel führt IMMER zur ursprünglichen CategoryView
                                        let targetCategory = trainingCoordinator.activeSetViewModel.originalCategory ?? group
                                        print("🔴 Navigating to CategoryView: \(targetCategory.rawValue)")
                                        
                                        if targetCategory != group {
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                navigationPath.append(NavigationDestination.muscleCategory(targetCategory))
                                            }
                                        }
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
