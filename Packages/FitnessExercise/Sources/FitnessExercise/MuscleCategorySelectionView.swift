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

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private enum SelectionLayoutConstants {
    static let horizontalPadding: CGFloat = AppStyle.Padding.screenHorizontal
    static let verticalSpacing: CGFloat = 10
}

private enum ViewMode {
    case overview
    case list
}

public struct MuscleCategorySelectionView: View {
    @State private var viewModel = MuscleCategorySelectionViewModel()
    @Environment(AppRouter.self) private var router
    @Environment(UIOverlayState.self) private var overlayState
    @State private var currentViewMode: ViewMode = .overview
    @State private var filterPillBounce: Bool = false
    @State private var filterBounceMode: ViewMode? = nil
    @Namespace private var filterNamespace
    @State private var analyticsViewModel = AnalyticsViewModel()
    @State private var isShowingExercisePicker = false
    @State private var editingExercise: Exercise?
    @State private var editingCategory: MuscleCategoryGroup?
    @State private var exerciseFormViewModel = ExerciseFormViewModel()
    @State private var pickerViewModel: MuscleCategoryViewModel?
    @State private var showCategorySelection = false
    @State private var isFilterBarVisible = true
    @State private var lastScrollOffset: CGFloat = 0

    private var coordinatorCache: TrainingCoordinatorCaching
    private var workoutStorage: WorkoutStoring

    /// T8a: Live-bound list of all `ExerciseModel`s for the current workout
    /// (across **all** categories). Replaces the legacy
    /// `viewModel.exercisesByCategory` snapshot path used by `allExercisesList`.
    /// View identity is rebound on workout switch via `.id(viewModel.currentWorkoutId)`
    /// so SwiftData re-initialises this `@Query` with the new workout id.
    @Query private var allWorkoutModels: [ExerciseModel]

    public init() {
        self.coordinatorCache = Container.shared.trainingCoordinatorCache()
        self.workoutStorage = Container.shared.workoutStorage()

        // Build the @Query predicate against the denormalised `workoutId` (T3 schema).
        // No category filter: list-mode renders every category in one flat list.
        // We read currentWorkout directly from the Factory-registered storage to avoid
        // instantiating a second ViewModel (the @State viewModel above is not yet
        // available in init — property-wrapper ordering). DI returns the same
        // singleton instance the @State viewModel will use.
        // Falls back to a sentinel UUID when no workout is selected so the predicate
        // matches nothing; the view rebinds via `.id(viewModel.currentWorkoutId)`
        // once a workout exists.
        let wid = Container.shared.workoutStorage().currentWorkout?.id ?? UUID()
        _allWorkoutModels = Query(
            filter: #Predicate<ExerciseModel> { exercise in
                exercise.workoutId == wid
            }
        )
    }

    private var adaptiveColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: SelectionLayoutConstants.verticalSpacing),
            GridItem(.flexible(), spacing: SelectionLayoutConstants.verticalSpacing),
        ]
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            AppStyle.Color.backgroundColor.ignoresSafeArea()

            VStack {
                Spacer()

                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.clear, location: 0.0),
                        .init(color: Color.black.opacity(0.6), location: 0.4),
                        .init(color: Color.black.opacity(0.8), location: 0.7),
                        .init(color: Color.black.opacity(0.9), location: 0.9),
                        .init(color: Color.black, location: 1.0),
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: safeAreaInset + 44)
                .allowsHitTesting(false)
                .offset(y: 34)
            }
            .zIndex(2)

            VStack(spacing: 0) {
                WorkoutDropdownView(workoutName: workoutStorage.currentWorkout?.name ?? L10n.workoutFallbackName)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppStyle.Padding.horizontal)
                    .padding(.top, AppStyle.Padding.titleTop)
                    .padding(.bottom, AppStyle.Padding.titleBottom)

                ScrollView {
                    VStack(spacing: 0) {
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: geometry.frame(in: .named("scroll")).minY
                            )
                        }
                        .frame(height: 0)
                        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                            if offset < 0 {
                                let scrollDelta = offset - lastScrollOffset

                                if abs(scrollDelta) > 10 {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        if scrollDelta < 0 {
                                            isFilterBarVisible = false
                                        } else {
                                            isFilterBarVisible = true
                                        }
                                    }
                                    lastScrollOffset = offset
                                }
                            } else {
                                if !isFilterBarVisible {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        isFilterBarVisible = true
                                    }
                                }
                                lastScrollOffset = offset
                            }
                        }

                        if currentViewMode == .overview {
                            LazyVGrid(
                                columns: adaptiveColumns,
                                spacing: SelectionLayoutConstants.verticalSpacing
                            ) {
                                categoryList
                            }
                            .padding(.horizontal, SelectionLayoutConstants.horizontalPadding)
                        } else {
                            LazyVStack(spacing: ExerciseCardLayout.CategoryTile.verticalSpacing) {
                                allExercisesList
                            }
                            .padding(.horizontal, 0)
                        }
                        Spacer(minLength: safeAreaInset + 24)
                    }
                }
                .coordinateSpace(name: "scroll")
            }

            if isFilterBarVisible && overlayState.exerciseSelectionMode == .none {
                VStack {
                    Spacer()

                    ZStack(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 100)
                            .contentShape(Rectangle())
                            .allowsHitTesting(true)

                        HStack {
                            Spacer()
                            filterToggleView
                        }
                        .padding(.horizontal, SelectionLayoutConstants.horizontalPadding)
                        .padding(.bottom, safeAreaInset + 24)
                    }
                }
                .zIndex(3)
                .transition(.opacity)
            }

            if overlayState.showWorkoutDropdown {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            overlayState.showWorkoutDropdown = false
                        }
                    }
                    .overlay {
                        WorkoutPickerView(
                            workouts: workoutStorage.workouts,
                            currentWorkout: workoutStorage.currentWorkout,
                            onSelect: { viewModel.selectWorkout($0) }
                        )
                    }
                    .zIndex(4)
            }

            if overlayState.showSelectionMiniMenu {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        overlayState.showSelectionMiniMenu = false
                        showCategorySelection = false
                    }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        MiniActionMenuView(
                            title: currentViewMode == .list && showCategorySelection ? L10n.newExercise : nil,
                            items: currentViewMode == .list ? (showCategorySelection ? categoryMenuItems : newExerciseMenuItems) : resetMenuItems,
                            width: selectionMenuWidth,
                            minHeight: currentViewMode == .list && showCategorySelection ? 280 : 140
                        )
                        .padding(.trailing, 16)
                    }
                    .padding(.bottom, safeAreaInset - 50)
                }
                .transition(.opacity)
                .zIndex(3)
            }

            if isShowingExercisePicker {
                if let editingCategory = editingCategory {
                    Color.clear.onAppear { overlayState.isEditingSheetVisible = true }
                    selectionEditPickerView(category: editingCategory)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .transition(.identity)
                        .zIndex(5)
                        .ignoresSafeArea(edges: .bottom)
                        .onDisappear { overlayState.isEditingSheetVisible = false }
                }
            }
        }
        .background(AppStyle.Color.backgroundColor)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
#endif
        .id(viewModel.currentWorkoutId)
        .onAppear {
            // The card grid is `@Query`-driven for live updates. This refresh
            // keeps `viewModel.exercisesByCategory` in sync as the backing
            // store for the legacy Form/Picker write path.
            viewModel.refreshExercises()
        }
        .onChange(of: overlayState.commitExerciseSelection) { _, _ in
            commitSelectionIfNeeded()
        }
    }

    private var newExerciseMenuItems: [MiniActionMenuItem] {
        // Order: New Exercise first, then the de/activate items at the end
        // (Activate before Deactivate) — same ordering as the category view.
        var items: [MiniActionMenuItem] = []

        items.append(MiniActionMenuItem(
            icon: "plus",
            title: L10n.newExercise,
            isDestructive: false
        ) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                showCategorySelection = true
            }
        })

        if hasDeactivatedExercises {
            items.append(MiniActionMenuItem(icon: "checkmark", title: L10n.exerciseActivate, isDestructive: false) {
                overlayState.showSelectionMiniMenu = false
                overlayState.selectedExerciseIds = []
                overlayState.exerciseSelectionMode = .activate
            })
        }

        if hasDeactivatableExercises {
            items.append(MiniActionMenuItem(icon: "xmark", title: L10n.exerciseDeactivate, isDestructive: false) {
                overlayState.showSelectionMiniMenu = false
                overlayState.selectedExerciseIds = []
                overlayState.exerciseSelectionMode = .deactivate
            })
        }

        return items
    }

    private var categoryMenuItems: [MiniActionMenuItem] {
        MuscleCategoryGroup.allCases.map { category in
            MiniActionMenuItem(
                icon: category.defaultIconName,
                title: category.displayName,
                isDestructive: false
            ) {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    overlayState.showSelectionMiniMenu = false
                    showCategorySelection = false
                }
                openExercisePickerForCategory(category)
            }
        }
    }

    private var resetMenuItems: [MiniActionMenuItem] {
        [
            MiniActionMenuItem(
                icon: "xmark",
                title: "Reset all",
                isDestructive: false,
                action: {
                    overlayState.showSelectionMiniMenu = false
                    showCategorySelection = false
                    viewModel.resetAllExercises()
                }
            ),
        ]
    }

    private func selectViewMode(_ mode: ViewMode) {
        guard mode != currentViewMode else { return }
        withAnimation(.smooth) { currentViewMode = mode }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) { filterPillBounce = true }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { filterBounceMode = mode }
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) { filterPillBounce = false }
            try? await Task.sleep(for: .milliseconds(50))
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) { filterBounceMode = nil }
        }
    }

    private func openExercisePickerForCategory(_ category: MuscleCategoryGroup) {
        editingCategory = category
        editingExercise = nil
        exerciseFormViewModel.loadExercise(nil, category: category)
        pickerViewModel = MuscleCategoryViewModel(group: category)
        isShowingExercisePicker = true
    }

    private func resetEditingState() {
        isShowingExercisePicker = false
        editingExercise = nil
        editingCategory = nil
        pickerViewModel = nil
        exerciseFormViewModel.clearForm()
    }

    @ViewBuilder
    private func selectionEditPickerView(category: MuscleCategoryGroup) -> some View {
        let onSave: () -> Void = {
            if let exercise = exerciseFormViewModel.createOrUpdateExercise() {
                if editingExercise != nil {
                    viewModel.updateExercise(exercise, category: category)
                } else {
                    viewModel.addExercise(exercise, category: category)
                }
            }
            resetEditingState()
        }
        let onCancel: () -> Void = {
            resetEditingState()
        }

        switch exerciseFormViewModel.editMode {
        case .full:
            if let vm = pickerViewModel {
                ExercisePickerView(
                    formViewModel: exerciseFormViewModel,
                    title: editingExercise != nil ? L10n.cardEditTitle : L10n.newExercise,
                    isPresented: $isShowingExercisePicker,
                    onSave: onSave,
                    onCancel: onCancel,
                    repsRange: 1...50,
                    weightOptions: WeightOptionsGenerator.exerciseWeightOptions,
                    setsRange: 1...10,
                    viewModel: vm,
                    editingExercise: editingExercise
                )
            }
        case .name:
            if let vm = pickerViewModel {
                ExerciseNamePickerView(
                    formViewModel: exerciseFormViewModel,
                    isPresented: $isShowingExercisePicker,
                    onSave: onSave,
                    onCancel: onCancel,
                    viewModel: vm,
                    editingExercise: editingExercise
                )
            }
        case .weight:
            ExerciseWeightPickerView(
                formViewModel: exerciseFormViewModel,
                isPresented: $isShowingExercisePicker,
                onSave: onSave,
                onCancel: onCancel,
                repsRange: 1...50,
                weightOptions: WeightOptionsGenerator.exerciseWeightOptions,
                setsRange: 1...10
            )
        case .seat:
            ExerciseSeatPickerView(
                formViewModel: exerciseFormViewModel,
                isPresented: $isShowingExercisePicker,
                onSave: onSave,
                onCancel: onCancel
            )
        }
    }

    /// Tile grid for overview mode. Renders one `CategoryTileModelView` per
    /// `MuscleCategoryGroup` (always all cases — see `MuscleCategorySelectionViewModel.categories`).
    /// Identity is layered intentionally:
    ///   • `ForEach(..., id: \.self)` gives each tile a stable per-row identity
    ///     (the `MuscleCategoryGroup`), so SwiftUI diffs children correctly.
    ///   • The container-level `.id(workoutId)` on the `ForEach` itself forces
    ///     a fresh composition — and therefore a fresh `@Query<ExerciseModel>`
    ///     in every child — when the user switches workouts (SwiftData
    ///     captures the predicate at `@Query` init; identity reset is the
    ///     supported way to rebind, see reviewing-code-changes §14d).
    /// The `if let` lives at the container level: without a workout there are
    /// simply no tiles to render. Putting the unwrap on every tile would just
    /// duplicate the guard.
    @ViewBuilder
    private var categoryList: some View {
        if let workoutId = viewModel.currentWorkoutId {
            ForEach(viewModel.categories, id: \.self) { group in
                CategoryTileModelView(
                    group: group,
                    workoutId: workoutId,
                    hasActiveSetForCategory: viewModel.hasActiveSetForCategory(group),
                    onTap: { router.navigate(to: .muscleCategory(group)) }
                )
                .contentShape(Rectangle())
                .accessibilityIdentifier(HomeIDs.categoryTile(for: group.rawValue))
            }
            .id(workoutId)
        }
    }

    private let filterBarHeight: CGFloat = 52
    private let filterBarPadding: CGFloat = 3
    private var filterSelectionHeight: CGFloat { filterBarHeight - (filterBarPadding * 2) }
    private var filterSelectionWidth: CGFloat { filterSelectionHeight * 1.6 }
    private let filterIconSize: CGFloat = 30

    private var filterToggleView: some View {
        HStack(spacing: 0) {
            Button(action: { selectViewMode(.overview) }) {
                Image("filterIconBody")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: filterIconSize, height: filterIconSize)
                    .foregroundColor(currentViewMode == .overview ? AppStyle.Color.greenGlow : .white)
                    .scaleEffect(filterBounceMode == .overview ? 1.3 : (currentViewMode == .overview ? 1.15 : 1.0))
                    .frame(width: filterSelectionWidth, height: filterSelectionHeight)
                    .background {
                        if currentViewMode == .overview {
                            Capsule()
                                .fill(AppStyle.Color.white.opacity(AppStyle.Opacity.selectionTintFill))
                                .scaleEffect(y: filterPillBounce ? 1.4 : 1.0)
                                .matchedGeometryEffect(id: "filterSelection", in: filterNamespace)
                        }
                    }
            }
            .buttonStyle(.plain)

            Button(action: { selectViewMode(.list) }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: filterIconSize - 4, weight: .medium))
                    .foregroundColor(currentViewMode == .list ? AppStyle.Color.greenGlow : .white)
                    .scaleEffect(filterBounceMode == .list ? 1.3 : (currentViewMode == .list ? 1.15 : 1.0))
                    .frame(width: filterSelectionWidth, height: filterSelectionHeight)
                    .background {
                        if currentViewMode == .list {
                            Capsule()
                                .fill(AppStyle.Color.white.opacity(AppStyle.Opacity.selectionTintFill))
                                .scaleEffect(y: filterPillBounce ? 1.4 : 1.0)
                                .matchedGeometryEffect(id: "filterSelection", in: filterNamespace)
                        }
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(filterBarPadding)
        .background {
            if #available(iOS 26.0, macOS 26.0, *) {
                Capsule()
                    .fill(Color.clear)
                    .glassEffect()
            } else {
                Capsule()
                    .fill(.ultraThinMaterial)
            }
        }
        .clipShape(Capsule())
    }

    private var allExercisesList: some View {
        // T8a: Bug-1-style live-fix for the list-mode. Source is `allWorkoutModels`
        // (`@Query`), not `viewModel.exercisesByCategory`.
        //
        // Visibility: deactivated exercises are hidden by default; `.activate`
        // multi-select mode reveals them instead so they can be ticked.
        // Completed exercises keep their `(category, sortOrder)` slot — no
        // completion-based re-sort.
        // No jump in/out of selection mode: keep the normal "all active" list;
        // `.activate` additionally reveals the (hidden) deactivated exercises.
        // Selectability is decided per card (`isCardSelectable`).
        let mode = overlayState.exerciseSelectionMode
        let visible = allWorkoutModels.filter { model in
            let active = model.isActive ?? true
            return mode == .activate ? true : active
        }
        let sorted = visible.sorted { lhs, rhs in
            if lhs.category != rhs.category { return lhs.category < rhs.category }
            return lhs.sortOrder < rhs.sortOrder
        }

        return ForEach(sorted, id: \.id) { model in
            exerciseCard(for: model)
        }
    }

    private func exerciseCard(for model: ExerciseModel) -> some View {
        let category = model.categoryGroup
        let categoryCoordinator = coordinatorCache.coordinator(for: category)
        return ExerciseCardModelView(
            model: model,
            onEdit: { exerciseToEdit, mode in
                if currentViewMode == .list {
                    editingExercise = exerciseToEdit
                    editingCategory = category
                    exerciseFormViewModel.loadExercise(exerciseToEdit, category: category)
                    exerciseFormViewModel.editMode = mode
                    if mode == .full || mode == .name {
                        pickerViewModel = MuscleCategoryViewModel(group: category)
                    }
                    isShowingExercisePicker = true
                } else {
                    router.navigate(to: .muscleCategory(category))
                }
            },
            isEditable: true,
            analyticsViewModel: analyticsViewModel,
            activeSetViewModel: categoryCoordinator.activeSetViewModel,
            onStart: { exerciseToStart in
#if canImport(UIKit)
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
#endif

                router.navigate(to: .training(exerciseId: exerciseToStart.id, category: category))
            },
            onReset: { exerciseToReset in
                viewModel.resetExercise(exerciseToReset, category: category)
            },
            isActiveSetVisible: false,
            isResetEnabled: model.isCompleted,
            isInProgress: categoryCoordinator.isExerciseInProgress(model.id),
            isSelectable: isCardSelectable(model),
            isSelected: overlayState.selectedExerciseIds.contains(model.id),
            onToggleSelection: { _ in overlayState.toggleSelection(model.id) },
            onLongPress: overlayState.exerciseSelectionMode == .none
                ? { _ in startDeactivateSelection(model.id) }
                : nil
        )
    }

    /// Non-selectable cards render normally (no radio) so nothing jumps when the
    /// mode toggles. The rule lives in `ExerciseSelectionRules`; this view only
    /// supplies its in-progress source.
    private func isCardSelectable(_ model: ExerciseModel) -> Bool {
        ExerciseSelectionRules.isSelectable(
            mode: overlayState.exerciseSelectionMode,
            isActive: model.isActive ?? true,
            isCompleted: model.isCompleted,
            isInProgress: coordinatorCache.coordinator(for: model.categoryGroup).isExerciseInProgress(model.id)
        )
    }

    /// Long-press shortcut: enters deactivate selection mode with the pressed
    /// (idle) card already ticked — the Cancel | Deactivate bar appears immediately.
    private func startDeactivateSelection(_ id: UUID) {
        overlayState.selectedExerciseIds = [id]
        overlayState.exerciseSelectionMode = .deactivate
    }

    /// Applies the multi-select Save: de/activates every ticked exercise via the
    /// targeted update path, then clears the mode. Scene-guarded so only the
    /// foreground (home) scene commits — the shared `commitExerciseSelection`
    /// flag is also observed by a still-mounted pushed category screen.
    private func commitSelectionIfNeeded() {
        guard router.currentScene == .home else { return }
        guard overlayState.commitExerciseSelection else { return }
        let active = overlayState.exerciseSelectionMode == .activate
        for model in allWorkoutModels where overlayState.selectedExerciseIds.contains(model.id) {
            viewModel.setExerciseActive(model.toDomain(), active: active, category: model.categoryGroup)
        }
        overlayState.endExerciseSelection()
        viewModel.refreshExercises()
    }

    private var hasDeactivatedExercises: Bool {
        allWorkoutModels.contains { !($0.isActive ?? true) }
    }

    /// Gates the "Deactivate Exercise" menu item on the same rule the per-card
    /// radio uses — never shown when nothing is actually selectable.
    private var hasDeactivatableExercises: Bool {
        allWorkoutModels.contains {
            ExerciseSelectionRules.isSelectable(
                mode: .deactivate,
                isActive: $0.isActive ?? true,
                isCompleted: $0.isCompleted,
                isInProgress: coordinatorCache.coordinator(for: $0.categoryGroup).isExerciseInProgress($0.id)
            )
        }
    }

    @Environment(\.safeAreaInsets) private var safeAreaInsets
    private var safeAreaInset: CGFloat { safeAreaInsets.bottom }

#if canImport(UIKit)
    private var selectionMenuWidth: CGFloat { min(UIScreen.main.bounds.width * 0.55, 320) }
#else
    private var selectionMenuWidth: CGFloat { 320 }
#endif
}
