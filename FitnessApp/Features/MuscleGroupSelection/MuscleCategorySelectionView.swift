import SwiftUI

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private enum Constants {
    static let horizontalPadding: CGFloat = AppStyle.Padding.screenHorizontal
    static let verticalSpacing: CGFloat = 10

    enum CategoryTile {
        static let contentPadding: CGFloat = AppStyle.Padding.screenHorizontal
        static let verticalSpacing: CGFloat = 12
        static let iconSize: CGFloat = 80
    }

    enum ProgressBar {
        static let height: CGFloat = 9
    }
}

private struct ExerciseInfo {
    let total: Int
    let active: Int
    let completed: Int
    let isCompleted: Bool
    let progress: Double
    let hasActiveSet: Bool
    
    init(total: Int, active: Int, hasActiveSet: Bool) {
        self.total = total
        self.active = active
        self.completed = max(0, total - active)
        self.isCompleted = (active == 0 && total > 0 && !hasActiveSet)
        self.progress = total > 0 ? Double(completed) / Double(total) : 0.0
        self.hasActiveSet = hasActiveSet
    }
}

private enum ViewMode {
    case overview
    case list
}

struct MuscleCategorySelectionView: View {
    @StateObject private var viewModel = MuscleCategorySelectionViewModel()
    @StateObject private var trainingCoordinator: TrainingCoordinator
    @Binding var navigationPath: NavigationPath
    @EnvironmentObject private var overlayState: UIOverlayState
    @State private var currentViewMode: ViewMode = .overview
    @State private var filterPillBounce: Bool = false
    @State private var filterBounceMode: ViewMode? = nil
    @Namespace private var filterNamespace
    @State private var isShowingExercisePicker = false
    @State private var editingExercise: Exercise?
    @State private var editingCategory: MuscleCategoryGroup?
    @StateObject private var exerciseFormViewModel = ExerciseFormViewModel()
    @State private var showCategorySelection = false
    @State private var isFilterBarVisible = true
    @State private var lastScrollOffset: CGFloat = 0
    
    init(navigationPath: Binding<NavigationPath> = .constant(NavigationPath())) {
        self._navigationPath = navigationPath
        let selectionViewModel = MuscleCategorySelectionViewModel()
        
        _trainingCoordinator = StateObject(wrappedValue: TrainingCoordinator(
            findCategory: { exercise in
                return selectionViewModel.findCategoryForExercise(exercise)
            },
            onExerciseUpdate: { exercise, category in
                selectionViewModel.updateExercise(exercise, category: category)
            },
            onExerciseReset: { exercise, category in
                selectionViewModel.resetExercise(exercise, category: category)
            },
            onAddExercise: {},
            onResetAllExercises: {}
        ))
        
        _viewModel = StateObject(wrappedValue: selectionViewModel)
    }
    
    private var adaptiveColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: Constants.verticalSpacing),
            GridItem(.flexible(), spacing: Constants.verticalSpacing)
        ]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppStyle.Color.backgroundColor.ignoresSafeArea()
            
            let _ = trainingCoordinator.activeSetViewModel.objectWillChange
            
            VStack {
                Spacer()
                
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.clear, location: 0.0),
                        .init(color: Color.black.opacity(0.6), location: 0.4),
                        .init(color: Color.black.opacity(0.8), location: 0.7),
                        .init(color: Color.black.opacity(0.9), location: 0.9),
                        .init(color: Color.black, location: 1.0)
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
                WorkoutDropdownView()
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
                            spacing: Constants.verticalSpacing
                        ) {
                            categoryList
                        }
                        .padding(.horizontal, Constants.horizontalPadding)
                    } else {
                        let isActiveSetVisible = trainingCoordinator.isTrainingActive
                        
                        if isActiveSetVisible {
                            if let exercise = trainingCoordinator.currentExercise {
                                LazyVStack(spacing: 16) {
                                    ExerciseCardContainerView(
                                        viewModel: ExerciseCardViewModel(exercise: exercise) { updatedExercise in
                                            if let category = viewModel.findCategoryForExercise(exercise) {
                                                viewModel.updateExercise(updatedExercise, category: category)
                                            }
                                        },
                                        onEdit: { exerciseToEdit, _ in
                                            if let category = viewModel.findCategoryForExercise(exerciseToEdit) {
                                                navigationPath.append(NavigationDestination.muscleCategory(category))
                                            }
                                        },
                                        isEditable: !trainingCoordinator.activeSetViewModel.isSetInProgress,
                                        analyticsViewModel: AnalyticsViewModel(),
                                        activeSetViewModel: trainingCoordinator.activeSetViewModel,
                                        onStart: { exerciseToStart in
                                            if let category = viewModel.findCategoryForExercise(exerciseToStart) {
                                                navigationPath.append(NavigationDestination.training(exerciseToStart, category))
                                            }
                                        },
                                        onReset: { exerciseToReset in
                                            if let category = viewModel.findCategoryForExercise(exerciseToReset) {
                                                viewModel.resetExercise(exerciseToReset, category: category)
                                            }
                                        },
                                        isActiveSetVisible: isActiveSetVisible,
                                        isResetEnabled: exercise.isCompleted
                                    )
                                    
                                    TrainingSessionComponent(
                                        coordinator: trainingCoordinator,
                                        analyticsViewModel: AnalyticsViewModel()
                                    )
                                }
                            }
                        } else {
                            if trainingCoordinator.isTrainingActive && trainingCoordinator.currentExercise != nil {
                                LazyVStack(spacing: Constants.CategoryTile.verticalSpacing) {
                                    activeTrainingOnlyList
                                }
                                .padding(.horizontal, 0)
                            } else {
                                LazyVStack(spacing: Constants.CategoryTile.verticalSpacing) {
                                    allExercisesList
                                }
                                .padding(.horizontal, 0)
                            }
                        }
                    }
                    Spacer(minLength: safeAreaInset + 24)
                    }
                }
                .coordinateSpace(name: "scroll")
            }
            
            if isFilterBarVisible {
                VStack {
                    Spacer()
                    
                    ZStack(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 100)
                            .contentShape(Rectangle())
                            .allowsHitTesting(true)
                        
                        if !trainingCoordinator.isTrainingActive {
                            HStack {
                                Spacer()
                                filterToggleView
                            }
                            .padding(.horizontal, Constants.horizontalPadding)
                            .padding(.bottom, safeAreaInset + 24)
                        } else {
                            Text("Training Active")
                                .font(.headline)
                                .foregroundColor(AppStyle.Color.green)
                                .padding(.horizontal, Constants.horizontalPadding)
                                .padding(.bottom, safeAreaInset + 24)
                        }
                    }
                }
                .zIndex(3)
                .transition(.opacity)
            }
            
            TrainingActionBarComponent(
                coordinator: trainingCoordinator,
                exercises: viewModel.allExercises(),
                hasActiveExercise: trainingCoordinator.isTrainingActive
            )
            .padding(.bottom, safeAreaInset + 12)
            
            TrainingPickerComponent(coordinator: trainingCoordinator)
                .zIndex(1001)
            
            if overlayState.showWorkoutDropdown {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            overlayState.showWorkoutDropdown = false
                        }
                    }
                    .overlay {
                        WorkoutPickerView(onSelect: { viewModel.selectWorkout($0) })
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
                            title: currentViewMode == .list && showCategorySelection ? "New Exercise" : nil,
                            items: currentViewMode == .list ? (showCategorySelection ? categoryMenuItems : newExerciseMenuItems) : resetMenuItems,
                            width: min(UIScreen.main.bounds.width * 0.55, 320),
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
        .id("picker-\(trainingCoordinator.activeSetViewModel.isEditing)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .onAppear {
            viewModel.updateExerciseCounts()
        }
    }
    
    // MARK: - Mini Menu Items
    
    private var newExerciseMenuItems: [MiniActionMenuItem] {
        [
            MiniActionMenuItem(
                icon: "plus",
                title: "New Exercise",
                isDestructive: false
            ) {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    showCategorySelection = true
                }
            }
        ]
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
            )
        ]
    }
    
    private func selectViewMode(_ mode: ViewMode) {
        guard mode != currentViewMode else { return }
        withAnimation(.smooth) { currentViewMode = mode }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) { filterPillBounce = true }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { filterBounceMode = mode }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) { filterPillBounce = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) { filterBounceMode = nil }
        }
    }

    private func openExercisePickerForCategory(_ category: MuscleCategoryGroup) {
        editingCategory = category
        editingExercise = nil
        exerciseFormViewModel.loadExercise(nil, category: category)
        isShowingExercisePicker = true
    }
    
    private func resetEditingState() {
        isShowingExercisePicker = false
        editingExercise = nil
        editingCategory = nil
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
            ExercisePickerView(
                formViewModel: exerciseFormViewModel,
                title: editingExercise != nil ? "Edit Exercise" : "New Exercise",
                isPresented: $isShowingExercisePicker,
                onSave: onSave,
                onCancel: onCancel,
                saveDisabled: !exerciseFormViewModel.isFormValid,
                repsRange: 1...50,
                weightOptions: WeightOptionsGenerator.exerciseWeightOptions,
                setsRange: 1...10,
                viewModel: MuscleCategoryViewModel(group: category),
                editingExercise: editingExercise
            )
        case .name:
            ExerciseNamePickerView(
                formViewModel: exerciseFormViewModel,
                isPresented: $isShowingExercisePicker,
                onSave: onSave,
                onCancel: onCancel,
                viewModel: MuscleCategoryViewModel(group: category),
                editingExercise: editingExercise
            )
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

    private var categoryList: some View {
        ForEach(viewModel.categories, id: \.self) { group in
            Button(action: {
                if let activeSetVM = SessionTrainingCache.shared.activeSetVMs[group],
                   let activeExercise = activeSetVM.currentExercise {
                    navigationPath.append(NavigationDestination.training(activeExercise, group))
                } else {
                    navigationPath.append(NavigationDestination.muscleCategory(group))
                }
            }) {
                CategoryTileView(group: group, viewModel: viewModel)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityIdentifier("id_category_tile_\(group.rawValue)")
        }
    }
    
    // Filter toggle sizing - matching MenuBar proportions
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
                                .fill(Color.white.opacity(0.15))
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
                                .fill(Color.white.opacity(0.15))
                                .scaleEffect(y: filterPillBounce ? 1.4 : 1.0)
                                .matchedGeometryEffect(id: "filterSelection", in: filterNamespace)
                        }
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(filterBarPadding)
        .background {
            Group {
                if #available(iOS 26.0, *) {
                    Capsule()
                        .fill(Color.clear)
                        .glassEffect()
                } else {
                    LiquidGlassBackground(
                        cornerRadius: filterBarHeight / 2,
                        material: .ultraThinMaterial
                    )
                }
            }
        }
        .clipShape(Capsule())
    }
    
    private var activeTrainingOnlyList: some View {
        Group {
            if let activeExercise = trainingCoordinator.currentExercise,
               let category = viewModel.findCategoryForExercise(activeExercise) {
                
                Section {
                    ExerciseCardContainerView(
                        viewModel: ExerciseCardViewModel(exercise: activeExercise) { updatedExercise in
                            viewModel.updateExercise(updatedExercise, category: category)
                        },
                        onEdit: { exerciseToEdit, mode in
                            editingExercise = exerciseToEdit
                            editingCategory = category
                            exerciseFormViewModel.loadExercise(exerciseToEdit, category: category)
                            exerciseFormViewModel.editMode = mode
                            isShowingExercisePicker = true
                        },
                        isEditable: true,
                        analyticsViewModel: AnalyticsViewModel(),
                        activeSetViewModel: trainingCoordinator.activeSetViewModel,
                        onStart: { exerciseToStart in
                            navigationPath.append(NavigationDestination.training(exerciseToStart, category))
                        },
                        onReset: { exerciseToReset in
                            viewModel.resetExercise(exerciseToReset, category: category)
                        },
                        isActiveSetVisible: trainingCoordinator.isTrainingActive,
                        isResetEnabled: activeExercise.isCompleted
                    )
                }
            } else {
                EmptyView()
            }
        }
    }
    
    private var allExercisesWithCategory: [(exercise: Exercise, category: MuscleCategoryGroup)] {
        MuscleCategoryGroup.allCases.flatMap { category in
            viewModel.getExercises(for: category).map { (exercise: $0, category: category) }
        }
        .sorted { !$0.exercise.isCompleted && $1.exercise.isCompleted }
    }
    
    private var allExercisesList: some View {
        let items = allExercisesWithCategory
        
        return ForEach(items, id: \.exercise.id) { item in
            exerciseCard(for: item.exercise, category: item.category)
        }
        .onAppear {
            viewModel.updateExerciseCounts()
            
            if trainingCoordinator.isTrainingActive && trainingCoordinator.currentExercise != nil {
                currentViewMode = .list
            }
        }
    }
    
    private func exerciseCard(for exercise: Exercise, category: MuscleCategoryGroup) -> some View {
        ExerciseCardContainerView(
            viewModel: ExerciseCardViewModel(exercise: exercise) { updatedExercise in
                viewModel.updateExercise(updatedExercise, category: category)
            },
            onEdit: { exerciseToEdit, mode in
                if currentViewMode == .list {
                    editingExercise = exerciseToEdit
                    editingCategory = category
                    exerciseFormViewModel.loadExercise(exerciseToEdit, category: category)
                    exerciseFormViewModel.editMode = mode
                    isShowingExercisePicker = true
                } else {
                    navigationPath.append(NavigationDestination.muscleCategory(category))
                }
            },
            isEditable: true,
            analyticsViewModel: AnalyticsViewModel(),
            activeSetViewModel: trainingCoordinator.activeSetViewModel,
            onStart: { exerciseToStart in
                if trainingCoordinator.isTrainingActive && trainingCoordinator.currentExercise?.id != exerciseToStart.id {
                    return
                }
                
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                navigationPath.append(NavigationDestination.training(exerciseToStart, category))
            },
            onReset: { exerciseToReset in
                viewModel.resetExercise(exerciseToReset, category: category)
            },
            isActiveSetVisible: trainingCoordinator.isTrainingActive,
            isResetEnabled: exercise.isCompleted
        )
    }
    
    private var safeAreaInset: CGFloat {
        UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0
    }
}

// MARK: - Supporting Views

private struct CategoryTileView: View {
    let group: MuscleCategoryGroup
    @ObservedObject var viewModel: MuscleCategorySelectionViewModel
    
    var body: some View {
        let exerciseInfo = createExerciseInfo()
        
        CardBackground(
            backgroundColor: AppStyle.Color.exerciseCardBackground,
            useGlassEffect: true,
            addPadding: false
        ) {
            VStack(spacing: 8) {
                HStack {
                    Text(group.displayName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(exerciseInfo.isCompleted ? AppStyle.Color.greenGlow : AppStyle.Color.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if exerciseInfo.isCompleted {
                        ZStack {
                            Circle()
                                .fill(AppStyle.Color.greenGlow)
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(AppStyle.Color.exerciseCardBackground)
                        }
                    } else if exerciseInfo.total == 0 {
                        ZStack {
                            Circle()
                                .fill(AppStyle.Color.greenGlow)
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundColor(AppStyle.Color.greenBlack)
                        }
                    } else {
                        Spacer()
                            .frame(width: 32, height: 32)
                    }
                }
                .padding(.horizontal, Constants.CategoryTile.contentPadding)
                
                ZStack {
                    Circle()
                        .fill(AppStyle.Color.greenBlack)
                        .frame(width: Constants.CategoryTile.iconSize * 0.9, height: Constants.CategoryTile.iconSize * 0.9)
                        .blur(radius: 15)
                        .opacity(0.5)
                    
                    Image(group.defaultIconName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100, alignment: group.iconAlignment)
                        .clipped()
                        .foregroundColor(AppStyle.Color.white)
                }
                .frame(width: Constants.CategoryTile.iconSize, height: Constants.CategoryTile.iconSize)
                
                Spacer()
                    .frame(height: 3)
                
                if exerciseInfo.total > 0 {
                    HStack(spacing: 8) {
                        if !exerciseInfo.isCompleted {
                            ProgressBar(
                                progress: exerciseInfo.progress,
                                totalWidth: 90
                            )
                            .frame(height: Constants.ProgressBar.height)
                        }
                        
                        Spacer()
                        
                        Text("\(exerciseInfo.completed) of \(exerciseInfo.total)")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundColor(exerciseInfo.isCompleted ? AppStyle.Color.greenGlow : AppStyle.Color.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.horizontal, Constants.CategoryTile.contentPadding)
                } else {
                    HStack(spacing: 8) {
                        Spacer()
                        
                        Text(" ")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundColor(.clear)
                    }
                    .padding(.horizontal, Constants.CategoryTile.contentPadding)
                }
            }
            .padding(.vertical, 12)
            .overlay(
                exerciseInfo.isCompleted ?
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppStyle.Color.green.opacity(0.3))
                : nil
            )
        }
    }
    
    private func createExerciseInfo() -> ExerciseInfo {
        let count = viewModel.getExerciseCount(for: group) ?? (0, 0)
        let hasActiveSet = viewModel.hasActiveSetForCategory(group)
        return ExerciseInfo(total: count.total, active: count.active, hasActiveSet: hasActiveSet)
    }
    
}


private struct ProgressBar: View {
    let progress: Double
    let totalWidth: CGFloat
    
    private let fillColor = AppStyle.Color.greenGlow //Color(hex: "#59E9AB")
    private let trackColor = AppStyle.Color.progressTrack
    
    var body: some View {
        ZStack(alignment: .leading) {
            trackView
            progressView
        }
        .frame(width: totalWidth, height: Constants.ProgressBar.height)
    }
    
    private var trackView: some View {
        Capsule()
            .fill(trackColor)
            .frame(width: totalWidth, height: Constants.ProgressBar.height)
    }
    
    private var progressView: some View {
        let clampedProgress = min(max(progress, 0.0), 1.0)
        return Capsule()
            .fill(fillColor)
            .frame(
                width: CGFloat(clampedProgress) * totalWidth,
                height: Constants.ProgressBar.height
            )
    }
}
