import SwiftUI

private enum Constants {
    static let horizontalPadding: CGFloat = 15
    static let verticalSpacing: CGFloat = 10
    static let titleTopPadding: CGFloat = 0
    static let spacerHeight: CGFloat = 5
    static let topPadding: CGFloat = 16
    static let titleBottomSpacing: CGFloat = 5
    
    static let secondaryTextColor = Color(hex: "#46474B")
    
    enum CategoryTile {
        static let barWidth: CGFloat = 120
        static let chipVerticalPadding: CGFloat = 10
        static let contentPadding: CGFloat = 15
        static let itemSpacing: CGFloat = 12
        static let verticalSpacing: CGFloat = 12
        static let textSpacing: CGFloat = 28
        static let verticalPadding: CGFloat = 20
        static let circleSize: CGFloat = 80
        static let circleLineWidth: CGFloat = 6
        static let iconSize: CGFloat = 80
        static let iconSpacing: CGFloat = 16
    }
    
    enum ProgressBar {
        static let height: CGFloat = 9
        static let strokeWidth: CGFloat = 1
        static let cornerRadius: CGFloat = 8
    }
}

private enum AccessibilityIDs {
    static func categoryLabel(for group: MuscleCategoryGroup) -> String {
        "id_label_\(group.id)"
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
    case overview  // Kategorien als Kacheln
    case list      // Alle Übungen in Liste
}

struct MuscleCategorySelectionView: View {
    @StateObject private var viewModel = MuscleCategorySelectionViewModel()
    @StateObject private var trainingCoordinator: TrainingCoordinator
    @Binding var navigationPath: NavigationPath
    @EnvironmentObject private var overlayState: UIOverlayState
    @State private var currentViewMode: ViewMode = .overview
    
    // Exercise Picker State
    @State private var isShowingExercisePicker = false
    @State private var editingExercise: Exercise?
    @State private var editingCategory: MuscleCategoryGroup?
    @StateObject private var exerciseFormViewModel = ExerciseFormViewModel()
    
    // Mini Menu State
    @State private var showCategorySelection = false

    

    

    
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
    
    // 2 columns with same spacing as WorkoutsScreen
    private var adaptiveColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: Constants.verticalSpacing), // Same as WorkoutsScreen (12pt)
            GridItem(.flexible(), spacing: Constants.verticalSpacing)
        ]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppStyle.Color.backgroundColor.ignoresSafeArea()
            
            // Force observation of activeSetViewModel changes
            let _ = trainingCoordinator.activeSetViewModel.objectWillChange
            
            // Bottom gradient starting below menu bar and going down
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
                    if currentViewMode == .overview {
                        // Grid with same spacing as WorkoutsScreen
                        LazyVGrid(
                            columns: adaptiveColumns, 
                            spacing: Constants.verticalSpacing // Same as WorkoutsScreen (12pt)
                        ) {
                            categoryList
                        }
                        .padding(.horizontal, Constants.horizontalPadding)
                        .padding(.top, 16)
                    } else {
                        // List mode - check if training is active
                        let isActiveSetVisible = trainingCoordinator.isTrainingActive
                        
                        if isActiveSetVisible {
                            // Show only active exercise (like in MuscleCategoryView)
                            if let exercise = trainingCoordinator.currentExercise {
                                LazyVStack(spacing: 16) {
                                    ExerciseCardContainerView(
                                        viewModel: ExerciseCardViewModel(exercise: exercise) { updatedExercise in
                                            // Update exercise for its category
                                            if let category = viewModel.findCategoryForExercise(exercise) {
                                                viewModel.updateExercise(updatedExercise, category: category)
                                            }
                                        },
                                        onEdit: { exerciseToEdit in
                                            // Navigate to category for editing
                                            if let category = viewModel.findCategoryForExercise(exerciseToEdit) {
                                                navigationPath.append(NavigationDestination.muscleCategory(category))
                                            }
                                        },
                                        isEditable: !trainingCoordinator.activeSetViewModel.isSetInProgress,
                                        analyticsViewModel: AnalyticsViewModel(),
                                        activeSetViewModel: trainingCoordinator.activeSetViewModel,
                                        onStart: { exerciseToStart in
                                            // Navigate to TrainingView
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
                            // If there's an active training, show only that exercise
                            if trainingCoordinator.isTrainingActive && trainingCoordinator.currentExercise != nil {
                                LazyVStack(spacing: Constants.CategoryTile.verticalSpacing) {
                                    activeTrainingOnlyList
                                }
                                .padding(.horizontal, 0)
                                .padding(.top, 16)
                            } else {
                                // Show all exercises list
                                LazyVStack(spacing: Constants.CategoryTile.verticalSpacing) {
                                    allExercisesList
                                }
                                .padding(.horizontal, 0)
                                .padding(.top, 16)
                            }
                        }
                    }
                    // small spacer so last tile isn't glued to gesture area
                    Spacer(minLength: safeAreaInset + 24)
                }
            }
            
            // Filter Toggle above bottom menu bar
            VStack {
                Spacer()
                
                if !trainingCoordinator.isTrainingActive {
                    filterToggleView
                        .padding(.horizontal, Constants.horizontalPadding)
                        .padding(.bottom, safeAreaInset + 12)
                } else {
                    Text("Training Active")
                        .font(.headline)
                        .foregroundColor(AppStyle.Color.green)
                        .padding(.horizontal, Constants.horizontalPadding)
                        .padding(.bottom, safeAreaInset + 12)
                }
            }
            .zIndex(3)
            
            // Bottom Action Bar for active training (like in MuscleCategoryView)
            TrainingActionBarComponent(
                coordinator: trainingCoordinator,
                exercises: viewModel.allExercises(),
                hasActiveExercise: trainingCoordinator.isTrainingActive
            )
            .padding(.bottom, safeAreaInset + 12)
            
            // Training Picker Component - Centralized picker logic (moved inside ZStack)
            TrainingPickerComponent(coordinator: trainingCoordinator)
                .zIndex(1001)  // Ensure it's above everything including bottom menu bar
            
            // Workout picker overlay
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
            
            // Selection mini menu overlay
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
            
            // Exercise picker overlay (like in MuscleCategoryView)
            if isShowingExercisePicker {
                if let editingCategory = editingCategory {
                    Color.clear.onAppear { overlayState.isEditingSheetVisible = true }
                    ExercisePickerView(
                        formViewModel: exerciseFormViewModel,
                        title: editingExercise != nil ? "Edit Exercise" : "New Exercise",
                        isPresented: $isShowingExercisePicker,
                        onSave: {
                            // Handle save logic - same as in MuscleCategoryView
                            if let exercise = exerciseFormViewModel.createOrUpdateExercise() {
                                if editingExercise != nil {
                                    // Update existing exercise
                                    viewModel.updateExercise(exercise, category: editingCategory)
                                } else {
                                    // Add new exercise
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
    
    private var headerView: some View {
        HStack {
            Text("Dein Workout")
                .font(AppStyle.Font.navigationHeadline)
                .foregroundColor(AppStyle.Color.white)
                .padding(.top, Constants.titleTopPadding)
                .padding(.bottom, Constants.titleBottomSpacing)
                .frame(maxWidth: .infinity, alignment: .leading)
            

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
        editingExercise = nil // New exercise
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
                    // Active training: Navigate directly to TrainingView
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
            // Category Option
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
                        .foregroundColor(currentViewMode == .overview ? .white : .white.opacity(0.6))
                    
                    Text("Category")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(currentViewMode == .overview ? .white : .white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(
                    currentViewMode == .overview ? Color.white.opacity(0.12) : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            
            // Exercise Option
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentViewMode = .list
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(currentViewMode == .list ? .white : .white.opacity(0.6))
                    
                    Text("Exercise")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(currentViewMode == .list ? .white : .white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(
                    currentViewMode == .list ? Color.white.opacity(0.12) : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(2)
        .background(
            Group {
                if #available(iOS 26.0, *) {
                    Color.clear
                        .glassEffect(in: .rect(cornerRadius: 16))
                } else {
                    LiquidGlassBackground(
                        cornerRadius: 16,
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
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                            // In active training mode, open ExercisePickerView
                            editingExercise = exerciseToEdit
                            editingCategory = category
                            exerciseFormViewModel.loadExercise(exerciseToEdit, category: category)
                            isShowingExercisePicker = true
                        },
                        isEditable: true,
                        analyticsViewModel: AnalyticsViewModel(),
                        activeSetViewModel: trainingCoordinator.activeSetViewModel,
                        onStart: { exerciseToStart in
                            // Navigate back to TrainingView for the same exercise
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
                                // Update exercise and save
                                viewModel.updateExercise(updatedExercise, category: category)
                            },
                            onEdit: { exerciseToEdit in
                                // In list view, open ExercisePickerView instead of navigating
                                if currentViewMode == .list {
                                    editingExercise = exerciseToEdit
                                    editingCategory = category
                                    // Configure the form view model
                                    exerciseFormViewModel.loadExercise(exerciseToEdit, category: category)
                                    isShowingExercisePicker = true
                                } else {
                                    // Navigate to category and trigger edit (original behavior for overview)
                                    navigationPath.append(NavigationDestination.muscleCategory(category))
                                }
                            },
                            isEditable: true,
                            analyticsViewModel: AnalyticsViewModel(),
                            activeSetViewModel: trainingCoordinator.activeSetViewModel,
                            onStart: { exerciseToStart in
                                // Don't allow starting new training if another is already active
                                if trainingCoordinator.isTrainingActive && trainingCoordinator.currentExercise?.id != exerciseToStart.id {
                                    return // Block starting different exercise
                                }
                                
                                // Add haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                
                                // Navigate to TrainingView
                                TrainingNavigationHelper.navigateToTraining(
                                    exercise: exerciseToStart,
                                    category: category,
                                    navigationPath: &navigationPath
                                )
                            },
                            onReset: { exerciseToReset in
                                // Reset exercise
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
            // Refresh exercise data when view appears (e.g., returning from TrainingView)
            viewModel.updateExerciseCounts()
            
            // If there's an active training, automatically switch to list mode to show only the active exercise
            if trainingCoordinator.isTrainingActive && trainingCoordinator.currentExercise != nil {
                currentViewMode = .list
            }
        }
    }
    

    

    

    
    private var safeAreaInset: CGFloat {
        UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0
    }
    

    

    

}

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
                        .foregroundColor(AppStyle.Color.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    CustomChip(
                        text: getChipText(exerciseInfo),
                        isCompleted: exerciseInfo.isCompleted,
                        width: 60,
                        verticalPadding: 6
                    )
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
                
                HStack(spacing: 8) {
                    ProgressBar(
                        progress: exerciseInfo.progress,
                        totalWidth: 90
                    )
                    .frame(height: Constants.ProgressBar.height)
                    
                    Spacer()
                    
                    Text("\(exerciseInfo.completed) of \(exerciseInfo.total)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppStyle.Color.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(.horizontal, Constants.CategoryTile.contentPadding)
            }
            .padding(.vertical, 12)
        }
    }
    
    private func createExerciseInfo() -> ExerciseInfo {
        let count = viewModel.getExerciseCount(for: group) ?? (0, 0)
        let hasActiveSet = viewModel.hasActiveSetForCategory(group)
        return ExerciseInfo(total: count.total, active: count.active, hasActiveSet: hasActiveSet)
    }
    
    private func getChipText(_ exerciseInfo: ExerciseInfo) -> String {
        if exerciseInfo.total == 0 {
            return "Not Set"
        } else if exerciseInfo.completed == exerciseInfo.total && !exerciseInfo.hasActiveSet {
            return "Done"
        } else if exerciseInfo.active == exerciseInfo.total && !exerciseInfo.hasActiveSet {
            return "Todo"
        } else {
            return "Active"
        }
    }
    
}


private struct CustomChip: View {
    let text: String
    let isCompleted: Bool
    let width: CGFloat
    let verticalPadding: CGFloat
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(textColor)
            .frame(width: width)
            .padding(.vertical, verticalPadding)
            .background(chipBackground)
            .overlay(chipOverlay)
    }
    
    private var textColor: Color {
        return AppStyle.Color.white
    }
    
    private var chipBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(AppStyle.Color.greenBlack)
    }
    
    private var chipOverlay: some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(borderColor, lineWidth: 1)
    }
    
    private var borderColor: Color {
        if text == "Active" || text == "Done" {
            return AppStyle.Color.greenGlow
        } else {
            return AppStyle.Color.white
        }
    }
}

private struct ProgressBar: View {
    let progress: Double
    let totalWidth: CGFloat
    
    private let fillColor = Color(hex: "#59E9AB")
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
        Capsule()
            .fill(fillColor)
            .frame(
                width: CGFloat(progress.clamped(to: 0...1)) * totalWidth,
                height: Constants.ProgressBar.height
            )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
