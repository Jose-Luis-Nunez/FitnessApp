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
                Text(group.displayName)
                    .font(AppStyle.Font.navigationHeadline)
                    .foregroundColor(AppStyle.Color.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppStyle.Padding.horizontal)
                    .padding(.top, AppStyle.Padding.titleTop)
                    .padding(.bottom, AppStyle.Padding.titleBottom)

                ScrollView {
                    LazyVStack(spacing: 4) {
                        exerciseListSection
                            .padding(.horizontal, 0)

                        TrainingSessionComponent(
                            coordinator: trainingCoordinator,
                            onEdit: { exercise, mode in
                                withAnimation {
                                    formViewModel.loadExercise(exercise, category: group)
                                    formViewModel.editMode = mode
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
                Color.clear.onAppear { overlayState.isEditingSheetVisible = true }
                editPickerView
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .shadow(radius: 5)
                    .transition(.move(edge: .bottom))
                    .zIndex(3)
                    .ignoresSafeArea(edges: .bottom)
                    .onDisappear { overlayState.isEditingSheetVisible = false }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
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
    private var editPickerView: some View {
        let onSave: () -> Void = {
            if let exercise = formViewModel.createOrUpdateExercise() {
                if formViewModel.editingExercise != nil {
                    viewModel.updateExercise(exercise)
                } else {
                    viewModel.add(exercise, atTop: true)
                }
            }
        }
        let onCancel: () -> Void = {
            formViewModel.clearForm()
        }

        switch formViewModel.editMode {
        case .full:
            ExercisePickerView(
                formViewModel: formViewModel,
                title: formViewModel.editingExercise != nil ? L10n.cardEditTitle : L10n.cardCreationTitle,
                isPresented: $formViewModel.showForm,
                onSave: onSave,
                onCancel: onCancel,
                saveDisabled: !formViewModel.isFormValid,
                repsRange: 1...30,
                weightOptions: WeightOptionsGenerator.exerciseWeightOptions,
                setsRange: 1...10,
                viewModel: viewModel,
                editingExercise: formViewModel.editingExercise
            )
        case .name:
            ExerciseNamePickerView(
                formViewModel: formViewModel,
                isPresented: $formViewModel.showForm,
                onSave: onSave,
                onCancel: onCancel,
                viewModel: viewModel,
                editingExercise: formViewModel.editingExercise
            )
        case .weight:
            ExerciseWeightPickerView(
                formViewModel: formViewModel,
                isPresented: $formViewModel.showForm,
                onSave: onSave,
                onCancel: onCancel,
                repsRange: 1...30,
                weightOptions: WeightOptionsGenerator.exerciseWeightOptions,
                setsRange: 1...10
            )
        case .seat:
            ExerciseSeatPickerView(
                formViewModel: formViewModel,
                isPresented: $formViewModel.showForm,
                onSave: onSave,
                onCancel: onCancel
            )
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
                        onEdit: { exercise, mode in
                            withAnimation {
                                formViewModel.loadExercise(exercise, category: group)
                                formViewModel.editMode = mode
                                formViewModel.toggleForm()
                            }
                        },
                        isEditable: !trainingCoordinator.activeSetViewModel.isSetInProgress,
                        analyticsViewModel: analyticsViewModel,
                        activeSetViewModel: trainingCoordinator.activeSetViewModel,
                        onStart: { selectedExercise in
                            navigationPath.append(NavigationDestination.training(selectedExercise, group))
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
                        onEdit: { exercise, mode in
                            withAnimation {
                                formViewModel.loadExercise(exercise, category: group)
                                formViewModel.editMode = mode
                                formViewModel.toggleForm()
                            }
                        },
                        isEditable: true,
                        analyticsViewModel: analyticsViewModel,
                        activeSetViewModel: trainingCoordinator.activeSetViewModel,
                        onStart: { selectedExercise in
                            navigationPath.append(NavigationDestination.training(selectedExercise, group))
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
                        onEdit: { exercise, mode in
                            withAnimation {
                                formViewModel.loadExercise(exercise, category: group)
                                formViewModel.editMode = mode
                                formViewModel.toggleForm()
                            }
                        },
                        isEditable: true,
                        analyticsViewModel: analyticsViewModel,
                        activeSetViewModel: trainingCoordinator.activeSetViewModel,
                        onStart: { selectedExercise in
                            navigationPath.append(NavigationDestination.training(selectedExercise, group))
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
                            items: {
                                var items: [MiniActionMenuItem] = []
                                
                                // New Exercise
                                if viewModel.showNewExercise {
                                    items.append(MiniActionMenuItem(icon: "plus", title: "New Exercise", isDestructive: false) {
                                        withAnimation {
                                            formViewModel.loadExercise(nil, category: group)
                                            formViewModel.toggleForm()
                                            overlayState.showCategoryMiniMenu = false
                                        }
                                    })
                                }
                                
                                // Start Training
                                if viewModel.showStartTraining {
                                    items.append(MiniActionMenuItem(icon: "play.fill", title: "Start Training", isDestructive: false) {
                                        if let exercise = trainingCoordinator.currentExercise ?? viewModel.exercises.first(where: { !$0.isCompleted }) {
                                            navigationPath.append(NavigationDestination.training(exercise, group))
                                        }
                                        overlayState.showCategoryMiniMenu = false
                                    })
                                }
                                
                                // Cancel Training
                                if viewModel.showCancel {
                                    items.append(MiniActionMenuItem(icon: "xmark", title: "Cancel", isDestructive: false) {
                                        trainingCoordinator.activeSetViewModel.cancelActiveSet()
                                        
                                        let targetCategory = trainingCoordinator.activeSetViewModel.originalCategory ?? group
                                        if targetCategory != group {
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                navigationPath.append(NavigationDestination.muscleCategory(targetCategory))
                                            }
                                        }
                                        overlayState.showCategoryMiniMenu = false
                                    })
                                }
                                
                                // Reset
                                if viewModel.showReset {
                                    items.append(MiniActionMenuItem(icon: "arrow.counterclockwise", title: "Reset", isDestructive: false) {
                                        viewModel.showResetConfirmation = true
                                        overlayState.showCategoryMiniMenu = false
                                    })
                                }
                                
                                // FALLBACK: Always show at least "New Exercise" if no other items
                                if items.isEmpty {
                                    items.append(MiniActionMenuItem(icon: "plus", title: "New Exercise", isDestructive: false) {
                                        withAnimation {
                                            formViewModel.loadExercise(nil, category: group)
                                            formViewModel.toggleForm()
                                            overlayState.showCategoryMiniMenu = false
                                        }
                                    })
                                }
                                return items
                            }(),
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
