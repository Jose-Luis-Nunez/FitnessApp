import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif
import FitnessAnalytics
import FitnessCore
import FitnessResources
import FitnessTraining
import FitnessUI
@_spi(PersistenceUI) import FitnessPersistenceUI
@_spi(PersistenceUI) import FitnessStorage
import Factory

public struct MuscleCategoryView: View {
    public let group: MuscleCategoryGroup
    @State private var viewModel: MuscleCategoryViewModel
    @State private var formViewModel: ExerciseFormViewModel
    private var trainingCoordinator: TrainingCoordinator
    @State private var analyticsViewModel: AnalyticsViewModel
    @Environment(AppRouter.self) private var router

    /// T7b: Live-bound list of `ExerciseModel`s for the current workout + category.
    /// Replaces the `viewModel.exercises` snapshot path for the card rendering
    /// (Bug 1 fix): when the coordinator writes `model.isCompleted = true` after
    /// a finished session, SwiftData dispatches the change into this `@Query` and
    /// `ExerciseCardModelView` resolves the variant from the live `model.isCompleted`
    /// — no `refreshExercises()` roundtrip needed. The legacy `viewModel.exercises`
    /// path stays alive for the edit/picker/menu condition flags (`hasActiveExercise`,
    /// `hasCompletedExercises`); T8 deletes that path together with the observation loop.
    @Query private var categoryModels: [ExerciseModel]

    public init(group: MuscleCategoryGroup) {
        self.group = group
        let muscleCategoryViewModel = MuscleCategoryViewModel(group: group)
        self._viewModel = State(wrappedValue: muscleCategoryViewModel)
        self._formViewModel = State(wrappedValue: muscleCategoryViewModel.formViewModel)

        let coordinatorCache = Container.shared.trainingCoordinatorCache()
        let coordinator = coordinatorCache.coordinator(for: group)
        self.trainingCoordinator = coordinator
        self._analyticsViewModel = State(wrappedValue: coordinator.analyticsViewModel)

        coordinator.setOnAddExercise {
            withAnimation {
                muscleCategoryViewModel.formViewModel.loadExercise(nil, category: group)
                muscleCategoryViewModel.formViewModel.toggleForm()
            }
        }

        // Build the @Query predicate against the denormalised `workoutId` (T3 schema)
        // — avoids §14a/b predicate anti-patterns. If no workout is selected we fall
        // back to a sentinel UUID so the predicate matches nothing; the view is
        // rebound via `.id(viewModel.currentWorkoutId)` once a workout exists.
        let raw = group.rawValue
        let wid = muscleCategoryViewModel.currentWorkoutId ?? UUID()
        _categoryModels = Query(
            filter: #Predicate<ExerciseModel> { exercise in
                exercise.workoutId == wid && exercise.category == raw
            }
        )
    }

    private var bottomListPadding: CGFloat {
        if formViewModel.showForm { return 340 }
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
                    }
                    .padding(.bottom, bottomListPadding)
                }
                .offset(y: -10)
            }

            if formViewModel.showForm {
                Color.clear.onAppear { overlayState.isEditingSheetVisible = true }
                editPickerView
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .shadow(radius: 5)
                    .transition(.identity)
                    .zIndex(3)
                    .onDisappear { overlayState.isEditingSheetVisible = false }
            }
        }
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
#endif
        .id(viewModel.currentWorkoutId)
        .onAppear {
            // T7b: refresh keeps the legacy `viewModel.exercises` snapshot in sync
            // for the edit/picker flow (`hasActiveExercise`, `hasCompletedExercises`,
            // `add`, `updateExercise`). The card list itself is now `@Query`-driven
            // and does not depend on this anymore. T8 deletes both the snapshot
            // and this onAppear after the write side moves to SwiftData.
            viewModel.refreshExercises()
        }
        .onChange(of: trainingCoordinator.activeSessions.count) {
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
        model: ExerciseModel,
        isEditable: Bool,
        isActiveSetVisible: Bool,
        isResetEnabled: Bool,
        isInProgress: Bool = false
    ) -> some View {
        ExerciseCardModelView(
            model: model,
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
                router.navigate(to: .training(exerciseId: selectedExercise.id, category: group))
            },
            onReset: { selectedExercise in
                viewModel.resetExercise(selectedExercise)
            },
            isActiveSetVisible: isActiveSetVisible,
            isResetEnabled: isResetEnabled,
            isInProgress: isInProgress
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private var exerciseListSection: some View {
        // T7b: Bug 1 live-fix. Card rendering source is `categoryModels` (`@Query`),
        // not `viewModel.exercises`. Sort buckets read `model.isCompleted` directly,
        // matching the old DTO-based partitioning 1:1.
        let activeIds = Set(trainingCoordinator.activeSessions.keys)
        let sorted = categoryModels.sorted { $0.sortOrder < $1.sortOrder }

        let inProgressModels = sorted.filter { activeIds.contains($0.id) }
        let incompleteModels = sorted.filter { !$0.isCompleted && !activeIds.contains($0.id) }
        let completedModels = sorted.filter { $0.isCompleted && !activeIds.contains($0.id) }

        ForEach(inProgressModels, id: \.id) { model in
            makeCardContainer(
                model: model,
                isEditable: true,
                isActiveSetVisible: false,
                isResetEnabled: model.isCompleted,
                isInProgress: true
            )
        }

        ForEach(incompleteModels, id: \.id) { model in
            makeCardContainer(
                model: model,
                isEditable: true,
                isActiveSetVisible: false,
                isResetEnabled: model.isCompleted
            )
        }

        ForEach(completedModels, id: \.id) { model in
            makeCardContainer(
                model: model,
                isEditable: true,
                isActiveSetVisible: false,
                isResetEnabled: model.isCompleted
            )
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
                                        // T8c: route from the live `categoryModels` @Query instead of the
                                        // legacy `viewModel.exercises` snapshot. The Mini-Menu Bools above
                                        // (`showStartTraining`/`showReset`) still read the snapshot — they
                                        // are UI affordances, not routing decisions, so snapshot-latency is
                                        // tolerable. The routing target itself MUST be live: routing into a
                                        // freshly-completed Exercise would defeat the T7b live-fix.
                                        //
                                        // Post-T8d: navigation carries only the id; `TrainingView` resolves
                                        // it via `@Query` so the destination always renders the live model.
                                        let nextId = categoryModels.first(where: { !$0.isCompleted })?.id
                                        if let exerciseId = trainingCoordinator.currentExercise?.id ?? nextId {
                                            router.navigate(to: .training(exerciseId: exerciseId, category: group))
                                        }
                                        overlayState.showCategoryMiniMenu = false
                                    })
                                }

                                if viewModel.showCancel {
                                    items.append(MiniActionMenuItem(icon: "xmark", title: "Cancel", isDestructive: false) { [router, overlayState] in
                                        let activeIds = Array(trainingCoordinator.activeSessions.keys)
                                        for id in activeIds {
                                            trainingCoordinator.cancelTraining(for: id)
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
