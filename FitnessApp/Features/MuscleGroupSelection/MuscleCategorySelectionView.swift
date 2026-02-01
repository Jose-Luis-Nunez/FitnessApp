import SwiftUI

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private enum Constants {
    static let horizontalPadding: CGFloat = 15
    static let verticalSpacing: CGFloat = 10
    
    enum CategoryTile {
        static let contentPadding: CGFloat = 15
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
                ScrollView {
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
                        .padding(.top, 16)
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
                                        onEdit: { exerciseToEdit in
                                            if let category = viewModel.findCategoryForExercise(exerciseToEdit) {
                                                navigationPath.append(NavigationDestination.muscleCategory(category))
                                            }
                                        },
                                        isEditable: !trainingCoordinator.activeSetViewModel.isSetInProgress,
                                        analyticsViewModel: AnalyticsViewModel(),
                                        activeSetViewModel: trainingCoordinator.activeSetViewModel,
                                        onStart: { exerciseToStart in
                                            if let category = viewModel.findCategoryForExercise(exerciseToStart) {
                                                TrainingNavigationHelper.navigateToTraining(
                                                    exercise: exerciseToStart,
                                                    category: category,
                                                    navigationPath: &navigationPath
                                                )
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
                                .padding(.top, 16)
                            }
                        } else {
                            if trainingCoordinator.isTrainingActive && trainingCoordinator.currentExercise != nil {
                                LazyVStack(spacing: Constants.CategoryTile.verticalSpacing) {
                                    activeTrainingOnlyList
                                }
                                .padding(.horizontal, 0)
                                .padding(.top, 16)
                            } else {
                                LazyVStack(spacing: Constants.CategoryTile.verticalSpacing) {
                                    allExercisesList
                                }
                                .padding(.horizontal, 0)
                                .padding(.top, 16)
                            }
                        }
                    }
                    Spacer(minLength: safeAreaInset + 24)
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
                            filterToggleView
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
                        WorkoutPickerView(viewModel: viewModel)
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
                    ExercisePickerView(
                        formViewModel: exerciseFormViewModel,
                        title: editingExercise != nil ? "Edit Exercise" : "New Exercise",
                        isPresented: $isShowingExercisePicker,
                        onSave: {
                            if let exercise = exerciseFormViewModel.createOrUpdateExercise() {
                                if editingExercise != nil {
                                    viewModel.updateExercise(exercise, category: editingCategory)
                                } else {
                                    viewModel.addExercise(exercise, category: editingCategory)
                                }
                            }
                            resetEditingState()
                        },
                        onCancel: {
                            resetEditingState()
                        },
                        saveDisabled: !exerciseFormViewModel.isFormValid,
                        repsRange: 1...50,
                        weightOptions: WeightOptionsGenerator.generateExerciseWeightOptions(),
                        setsRange: 1...10,
                        viewModel: MuscleCategoryViewModel(group: editingCategory),
                        editingExercise: editingExercise
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .shadow(radius: 5)
                    .transition(.move(edge: .bottom).combined(with: .opacity).animation(.easeOut(duration: 0.25)))
                    .zIndex(5)
                    .ignoresSafeArea(edges: .bottom)
                    .onDisappear { overlayState.isEditingSheetVisible = false }
                }
            }
        }
        .background(AppStyle.Color.backgroundColor)
        .id("picker-\(trainingCoordinator.activeSetViewModel.isEditing)")
        .modifier(
            CustomToolbarModifier(
                navigationPath: $navigationPath,
                customTitleView: AnyView(WorkoutDropdownView(viewModel: viewModel)),
                showBackButton: false
            )
        )
        .navigationBarTitleDisplayMode(.inline)
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
                showCategorySelection = true
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
                overlayState.showSelectionMiniMenu = false
                showCategorySelection = false
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
    
    private var categoryList: some View {
        ForEach(viewModel.categories, id: \.self) { group in
            Button(action: {
                if let activeSetVM = SessionTrainingCache.shared.activeSetVMs[group],
                   let activeExercise = activeSetVM.currentExercise {
                    TrainingNavigationHelper.navigateToTraining(
                        exercise: activeExercise,
                        category: group,
                        navigationPath: &navigationPath
                    )
                } else {
                    navigationPath.append(NavigationDestination.muscleCategory(group))
                }
            }) {
                CategoryTileView(group: group, viewModel: viewModel)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
    }
    
    private var filterToggleView: some View {
        HStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentViewMode = .overview
                }
            }) {
                HStack(spacing: 8) {
                    Image("filterIconBody")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .foregroundColor(.white)
                    
                    Text("Category")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    currentViewMode == .overview ? Color.white.opacity(0.12) : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentViewMode = .list
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("Exercise")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    currentViewMode == .list ? Color.white.opacity(0.12) : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(2)
        .background(
            Group {
                if #available(iOS 26.0, *) {
                    Color.clear
                        .glassEffect(in: .rect(cornerRadius: 22))
                } else {
                    LiquidGlassBackground(
                        cornerRadius: 22,
                        material: .ultraThinMaterial,
                        tintOpacity: 0.0,
                        showsEdgeStroke: false,
                        showsCaustic: false,
                        shadowOpacity: 0.20,
                        lightnessBoostOpacity: 0.12
                    )
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
                        onEdit: { exerciseToEdit in
                            editingExercise = exerciseToEdit
                            editingCategory = category
                            exerciseFormViewModel.loadExercise(exerciseToEdit, category: category)
                            isShowingExercisePicker = true
                        },
                        isEditable: true,
                        analyticsViewModel: AnalyticsViewModel(),
                        activeSetViewModel: trainingCoordinator.activeSetViewModel,
                        onStart: { exerciseToStart in
                            TrainingNavigationHelper.navigateToTraining(
                                exercise: exerciseToStart,
                                category: category,
                                navigationPath: &navigationPath
                            )
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
    
    private var allExercisesList: some View {
        ForEach(MuscleCategoryGroup.allCases, id: \.id) { category in
            let exercises = viewModel.getExercises(for: category)
            if !exercises.isEmpty {
                Section {
                    ForEach(exercises, id: \.id) { exercise in
                        ExerciseCardContainerView(
                            viewModel: ExerciseCardViewModel(exercise: exercise) { updatedExercise in
                                viewModel.updateExercise(updatedExercise, category: category)
                            },
                            onEdit: { exerciseToEdit in
                                if currentViewMode == .list {
                                    editingExercise = exerciseToEdit
                                    editingCategory = category
                                    exerciseFormViewModel.loadExercise(exerciseToEdit, category: category)
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
                                
                                TrainingNavigationHelper.navigateToTraining(
                                    exercise: exerciseToStart,
                                    category: category,
                                    navigationPath: &navigationPath
                                )
                            },
                            onReset: { exerciseToReset in
                                viewModel.resetExercise(exerciseToReset, category: category)
                            },
                            isActiveSetVisible: trainingCoordinator.isTrainingActive,
                            isResetEnabled: exercise.isCompleted
                        )
                    }
                }
            }
        }
        .onAppear {
            viewModel.updateExerciseCounts()
            
            if trainingCoordinator.isTrainingActive && trainingCoordinator.currentExercise != nil {
                currentViewMode = .list
            }
        }
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
    private let trackColor = Color(hex: "#0A2726")
    
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
