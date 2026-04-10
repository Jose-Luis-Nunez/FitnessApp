import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import FitnessAnalytics
import FitnessCore
import FitnessResources
import FitnessTraining
import FitnessUI
import Factory

public struct MuscleCategoryView: View {
    public let group: MuscleCategoryGroup
    @State private var viewModel: MuscleCategoryViewModel
    @State private var formViewModel: ExerciseFormViewModel
    @State private var trainingCoordinator: TrainingCoordinator
    @State private var analyticsViewModel: AnalyticsViewModel
    @Environment(AppRouter.self) private var router

    public init(group: MuscleCategoryGroup) {
        self.group = group
        let muscleCategoryViewModel = MuscleCategoryViewModel(group: group)
        let sharedAnalyticsVM = AnalyticsViewModel()
        self._viewModel = State(wrappedValue: muscleCategoryViewModel)
        self._formViewModel = State(wrappedValue: muscleCategoryViewModel.formViewModel)
        self._analyticsViewModel = State(wrappedValue: sharedAnalyticsVM)

        self._trainingCoordinator = State(wrappedValue: TrainingCoordinator(
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
            onResetAllExercises: {},
            analyticsViewModel: sharedAnalyticsVM
        ))
    }

    private var bottomListPadding: CGFloat {
        if formViewModel.showForm { return 340 }
        if trainingCoordinator.activeSetViewModel.isEditing { return 240 }
        let hasActiveTraining = trainingCoordinator.activeSetViewModel.isSetInProgress
            || trainingCoordinator.activeSetViewModel.currentExercise != nil
        if hasActiveTraining { return safeAreaBottomInset + 100 }
        return safeAreaBottomInset + 40
    }

    @Environment(\.safeAreaInsets) private var safeAreaInsets
    private var safeAreaBottomInset: CGFloat { safeAreaInsets.bottom }

    @Environment(UIOverlayState.self) private var overlayState

    public var body: some View {
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
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
#endif
        .onAppear {
            viewModel.refreshExercises()
        }
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

    private func makeCardContainer(
        exercise: Exercise,
        isEditable: Bool,
        isActiveSetVisible: Bool,
        isResetEnabled: Bool
    ) -> some View {
        ExerciseCardContainerView(
            viewModel: viewModel.cardViewModel(for: exercise),
            onEdit: { exercise, mode in
                withAnimation {
                    formViewModel.loadExercise(exercise, category: group)
                    formViewModel.editMode = mode
                    formViewModel.toggleForm()
                }
            },
            isEditable: isEditable,
            analyticsViewModel: analyticsViewModel,
            activeSetViewModel: trainingCoordinator.activeSetViewModel,
            onStart: { selectedExercise in
                router.navigate(to: .training(selectedExercise, group))
            },
            onReset: { selectedExercise in
                viewModel.resetExercise(selectedExercise)
            },
            isActiveSetVisible: isActiveSetVisible,
            isResetEnabled: isResetEnabled
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private var exerciseListSection: some View {
        let isActiveSetVisible = trainingCoordinator.currentExercise != nil

        if isActiveSetVisible {
            if let exercise = trainingCoordinator.currentExercise {
                makeCardContainer(
                    exercise: exercise,
                    isEditable: !trainingCoordinator.activeSetViewModel.isSetInProgress,
                    isActiveSetVisible: true,
                    isResetEnabled: exercise.isCompleted
                )
            }
        } else {
            let incompleteExercises = viewModel.exercises.filter { !$0.isCompleted }
            let completedExercises = viewModel.exercises.filter { $0.isCompleted }

            ForEach(incompleteExercises, id: \.id) { exercise in
                makeCardContainer(
                    exercise: exercise,
                    isEditable: true,
                    isActiveSetVisible: false,
                    isResetEnabled: exercise.isCompleted
                )
            }

            ForEach(completedExercises, id: \.id) { exercise in
                makeCardContainer(
                    exercise: exercise,
                    isEditable: true,
                    isActiveSetVisible: false,
                    isResetEnabled: exercise.isCompleted
                )
            }
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
}

private extension MuscleCategoryView {
    var miniMenuOverlay: some View {
        ZStack {
            if overlayState.showCategoryMiniMenu {
                Color.black.opacity(0.001)
                    .ignoresSafeArea(.all)
                    .onTapGesture { overlayState.showCategoryMiniMenu = false }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        MiniActionMenuView(
                            title: nil,
                            items: {
                                var items: [MiniActionMenuItem] = []

                                if viewModel.showNewExercise {
                                    items.append(MiniActionMenuItem(icon: "plus", title: "New Exercise", isDestructive: false) {
                                        withAnimation {
                                            formViewModel.loadExercise(nil, category: group)
                                            formViewModel.toggleForm()
                                            overlayState.showCategoryMiniMenu = false
                                        }
                                    })
                                }

                                if viewModel.showStartTraining {
                                    items.append(MiniActionMenuItem(icon: "play.fill", title: "Start Training", isDestructive: false) {
                                        if let exercise = trainingCoordinator.currentExercise ?? viewModel.exercises.first(where: { !$0.isCompleted }) {
                                            router.navigate(to: .training(exercise, group))
                                        }
                                        overlayState.showCategoryMiniMenu = false
                                    })
                                }

                                if viewModel.showCancel {
                                    items.append(MiniActionMenuItem(icon: "xmark", title: "Cancel", isDestructive: false) { [router, overlayState] in
                                        trainingCoordinator.activeSetViewModel.cancelActiveSet()

                                        let targetCategory = trainingCoordinator.activeSetViewModel.originalCategory ?? group
                                        if targetCategory != group {
                                            Task { @MainActor in
                                                try? await Task.sleep(for: .milliseconds(100))
                                                router.navigate(to: .muscleCategory(targetCategory))
                                            }
                                        }
                                        overlayState.showCategoryMiniMenu = false
                                    })
                                }

                                if viewModel.showReset {
                                    items.append(MiniActionMenuItem(icon: "arrow.counterclockwise", title: "Reset", isDestructive: false) {
                                        viewModel.showResetConfirmation = true
                                        overlayState.showCategoryMiniMenu = false
                                    })
                                }

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
                            width: menuWidth,
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

#if canImport(UIKit)
    private var menuWidth: CGFloat { min(UIScreen.main.bounds.width * 0.55, 320) }
#else
    private var menuWidth: CGFloat { 320 }
#endif
}
