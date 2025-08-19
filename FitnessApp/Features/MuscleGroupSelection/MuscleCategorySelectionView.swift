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
        static let height: CGFloat = 10
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
    @StateObject private var activeSetViewModel = ActiveSetViewModel()
    @Binding var navigationPath: NavigationPath
    @EnvironmentObject private var overlayState: UIOverlayState
    @State private var currentViewMode: ViewMode = .overview
    
    init(navigationPath: Binding<NavigationPath> = .constant(NavigationPath())) {
        self._navigationPath = navigationPath
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            AppStyle.Color.backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Filter Toggle - only show when not training
                if activeSetViewModel.currentExercise == nil {
                    filterToggleView
                        .padding(.horizontal, Constants.horizontalPadding)
                        .padding(.top, Constants.topPadding)
                }
                
                ScrollView {
                    if currentViewMode == .overview {
                        LazyVStack(spacing: Constants.CategoryTile.verticalSpacing) {
                            categoryList
                        }
                        .padding(.horizontal, Constants.horizontalPadding)
                        .padding(.top, 16)
                    } else {
                        // List mode - check if training is active
                        let isActiveSetVisible = activeSetViewModel.currentExercise != nil
                        
                        if isActiveSetVisible {
                            // Show only active exercise (like in MuscleCategoryView)
                            if let exercise = activeSetViewModel.currentExercise {
                                LazyVStack(spacing: 12) {
                                    ExerciseCardContainerView(
                                        viewModel: ExerciseCardViewModel(exercise: exercise) { updatedExercise in
                                            // Update exercise for its category
                                            if let category = findCategoryForExercise(exercise) {
                                                viewModel.updateExercise(updatedExercise, category: category)
                                            }
                                        },
                                        onEdit: { exerciseToEdit in
                                            // Navigate to category for editing
                                            if let category = findCategoryForExercise(exerciseToEdit) {
                                                navigationPath.append(NavigationDestination.muscleCategory(category))
                                            }
                                        },
                                        isEditable: !activeSetViewModel.isSetInProgress,
                                        analyticsViewModel: AnalyticsViewModel(),
                                        activeSetViewModel: activeSetViewModel,
                                        onStart: { exerciseToStart in
                                            // Already active, this shouldn't happen
                                        },
                                        onReset: { exerciseToReset in
                                            if let category = findCategoryForExercise(exerciseToReset) {
                                                viewModel.resetExercise(exerciseToReset, category: category)
                                            }
                                        },
                                        isActiveSetVisible: isActiveSetVisible,
                                        isResetEnabled: exercise.isCompleted
                                    )
                                    .padding(.horizontal, Constants.horizontalPadding)
                                    
                                    // Add ActiveSetView with same padding as ActiveCardView
                                    if let currentExercise = activeSetViewModel.currentExercise {
                                        VStack(spacing: 16) {
                                            ActiveSetView(
                                                sets: currentExercise.sets,
                                                exercise: currentExercise,
                                                setProgress: .constant(activeSetViewModel.setProgress),
                                                viewModel: activeSetViewModel
                                            )
                                            .onAppear {
                                                if activeSetViewModel.isSetInProgress {
                                                    activeSetViewModel.startTimer()
                                                }
                                            }
                                            
                                            // Add TimerView like in MuscleCategoryView
                                            TimerView(viewModel: activeSetViewModel)
                                        }
                                    }
                                }
                                .padding(.top, 16)
                            }
                        } else {
                            // Show all exercises list
                            LazyVStack(spacing: 4) {
                                allExercisesList
                            }
                            .padding(.horizontal, 0)
                            .padding(.top, 16)
                        }
                    }
                    // small spacer so last tile isn't glued to gesture area
                    Spacer(minLength: safeAreaInset + 24)
                }
            }
            
            // Bottom Action Bar for active training (like in MuscleCategoryView)
            if currentViewMode == .list && activeSetViewModel.currentExercise != nil {
                BottomActionBarView(
                    viewModel: createBottomActionBarViewModel(),
                    onStart: {
                        guard let exercise = activeSetViewModel.currentExercise else { return }
                        if activeSetViewModel.currentSet == 0 && activeSetViewModel.setProgress.isEmpty {
                            activeSetViewModel.startSet(for: exercise, category: findCategoryForExercise(exercise) ?? .arms)
                        } else {
                            activeSetViewModel.startNextSet()
                        }
                    },
                    onCompleteSet: {
                        activeSetViewModel.stopTimer()
                        activeSetViewModel.completeCurrentSet()
                    },
                    onQuickDone: {
                        if let activeExercise = activeSetViewModel.currentExercise {
                            activeSetViewModel.startQuickDone(for: activeExercise, category: findCategoryForExercise(activeExercise) ?? .arms)
                        }
                    },
                    onCompleteAllQuickDone: {
                        activeSetViewModel.completeAllQuickDone()
                    },
                                                        onCategoryReset: {
                        activeSetViewModel.stopTimer()
                        // Reset the current exercise
                        if let exercise = activeSetViewModel.currentExercise,
                           let category = findCategoryForExercise(exercise) {
                            viewModel.resetExercise(exercise, category: category)
                        }
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
                        // Finish exercise when last set is completed - use shared service
                        activeSetViewModel.stopTimer()
                        if activeSetViewModel.isLastSetCompleted,
                           let exercise = activeSetViewModel.currentExercise,
                           let category = findCategoryForExercise(exercise) {
                            // Complete exercise with analytics saving
                            viewModel.completeExercise(exercise, category: category, setProgress: activeSetViewModel.setProgress)
                        }
                        activeSetViewModel.finishExercise()
                    },
                    onAddExercise: {
                        // Navigate to add exercise - not used in list view
                    },
                    onResetAllExercises: {
                        // Reset all exercises - not used in this context
                    }
                )
                .offset(y: -10)
                .zIndex(5)
            }
            
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
                    .onTapGesture { overlayState.showSelectionMiniMenu = false }
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        MiniActionMenuView(
                            title: nil,
                            items: [
                                MiniActionMenuItem(
                                    icon: viewModel.hasInactiveExercises() ? "xmark" : nil,
                                    title: viewModel.hasInactiveExercises() ? "Reset all" : "",
                                    isDestructive: false,
                                    action: {
                                        overlayState.showSelectionMiniMenu = false
                                        if viewModel.hasInactiveExercises() {
                                            viewModel.resetAllExercises()
                                        }
                                    }
                                )
                            ],
                            width: min(UIScreen.main.bounds.width * 0.55, 320),
                            minHeight: 140
                        )
                        .padding(.trailing, 16)
                    }
                    .padding(.bottom, safeAreaInset - 50)
                }
                .transition(.opacity)
                .zIndex(3)
            }
        }
        .background(AppStyle.Color.backgroundColor)
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
        Text("Dein Workout")
            .font(AppStyle.Font.navigationHeadline)
            .foregroundColor(AppStyle.Color.white)
            .padding(.top, Constants.titleTopPadding)
            .padding(.bottom, Constants.titleBottomSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var categoryList: some View {
        ForEach(viewModel.categories, id: \.self) { group in
            NavigationLink(value: NavigationDestination.muscleCategory(group)) {
                CategoryTileView(group: group, viewModel: viewModel)
            }
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
                .frame(height: 36)
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
                .frame(height: 36)
                .background(
                    currentViewMode == .list ? Color.white.opacity(0.12) : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(4)
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
                                // Navigate to category and trigger edit
                                navigationPath.append(NavigationDestination.muscleCategory(category))
                            },
                            isEditable: true,
                            analyticsViewModel: AnalyticsViewModel(),
                            activeSetViewModel: activeSetViewModel,
                            onStart: { exerciseToStart in
                                // Add haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                
                                // Start exercise training directly - stay in list view
                                activeSetViewModel.startSet(for: exerciseToStart, category: category)
                            },
                            onReset: { exerciseToReset in
                                // Reset exercise
                                viewModel.resetExercise(exerciseToReset, category: category)
                            },
                            isActiveSetVisible: activeSetViewModel.currentExercise != nil,
                            isResetEnabled: exercise.isCompleted
                        )
                        .padding(.vertical, 6)
                    }
                } header: {
                    HStack {
                        Text(category.displayName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(exercises.count) Übungen")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    
    private func findCategoryForExercise(_ exercise: Exercise) -> MuscleCategoryGroup? {
        for category in MuscleCategoryGroup.allCases {
            let exercises = viewModel.getExercises(for: category)
            if exercises.contains(where: { $0.id == exercise.id }) {
                return category
            }
        }
        return nil
    }
    

    
    private func createBottomActionBarViewModel() -> BottomActionBarViewModel {
        // Get all exercises across all categories for comprehensive view
        var allExercises: [Exercise] = []
        for category in MuscleCategoryGroup.allCases {
            allExercises.append(contentsOf: viewModel.getExercises(for: category))
        }
        
        return BottomActionBarViewModel(
            isSetInProgress: activeSetViewModel.isSetInProgress,
            currentSet: activeSetViewModel.currentSet,
            currentExercise: activeSetViewModel.currentExercise,
            hasActiveExercise: allExercises.contains { !$0.isCompleted },
            exercises: allExercises,
            isLastSetCompleted: activeSetViewModel.isLastSetCompleted,
            quickDoneModeActive: activeSetViewModel.quickDoneModeActive,
            quickDoneAllCompleted: activeSetViewModel.quickDoneAllCompleted,
            didEditCompleteSet: activeSetViewModel.didEditCompleteSet,
            didJustEditSet: activeSetViewModel.didJustEditSet,
            showResetAllExercisesButton: false
        )
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
            HStack(spacing: 0) {
                categoryInfoView(exerciseInfo: exerciseInfo)
                Spacer()
                progressSection(exerciseInfo: exerciseInfo)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private func categoryInfoView(exerciseInfo: ExerciseInfo) -> some View {
        HStack(spacing: Constants.CategoryTile.iconSpacing) {
            ZStack {
                Circle()
                    .fill(AppStyle.Color.greenBlack)
                    .frame(width: Constants.CategoryTile.iconSize * 0.9, height: Constants.CategoryTile.iconSize * 0.9)
                    .blur(radius: 15)
                    .opacity(0.5)
                
                Image(group.defaultIconName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: Constants.CategoryTile.iconSize, height: Constants.CategoryTile.iconSize, alignment: group.iconAlignment)
                    .clipped()
                    .foregroundColor(AppStyle.Color.white)
            }
            .frame(width: Constants.CategoryTile.iconSize, height: Constants.CategoryTile.iconSize)
            
            VStack(alignment: .leading, spacing: Constants.CategoryTile.textSpacing) {
                Text(group.displayName)
                    .font(AppStyle.Font.categorySelectionNameFont)
                    .foregroundColor(AppStyle.Color.white)
                
                Text("\(exerciseInfo.completed) of \(exerciseInfo.total) completed")
                    .font(AppStyle.Font.defaultFont)
                    .foregroundColor(AppStyle.Color.white)
            }
        }
        .padding(.vertical, Constants.CategoryTile.verticalPadding)
        .padding(.horizontal, Constants.CategoryTile.contentPadding)
    }
    
    private func progressSection(exerciseInfo: ExerciseInfo) -> some View {
        HStack(spacing: Constants.CategoryTile.itemSpacing) {
            CircularProgressView(
                progress: exerciseInfo.progress,
                statusText: getChipText(exerciseInfo),
                isCompleted: exerciseInfo.isCompleted
            )
            .accessibilityIdentifier(AccessibilityIDs.categoryLabel(for: group))
            
            Image(systemName: "chevron.right")
                .foregroundColor(AppStyle.Color.white)
                .imageScale(.medium)
        }
        .padding(.vertical, Constants.CategoryTile.verticalPadding)
        .padding(.horizontal, Constants.CategoryTile.contentPadding)
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
            return "Completed"
        } else if exerciseInfo.active == exerciseInfo.total && !exerciseInfo.hasActiveSet {
            return "Not Started"
        } else {
            return "Active"
        }
    }
}

private struct CircularProgressView: View {
    let progress: Double
    let statusText: String
    let isCompleted: Bool
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(
                    Constants.secondaryTextColor,
                    lineWidth: Constants.CategoryTile.circleLineWidth
                )
            
            // Progress circle
            Circle()
                .trim(from: 0, to: CGFloat(progress.clamped(to: 0...1)))
                .stroke(
                    progressColor,
                    style: StrokeStyle(
                        lineWidth: Constants.CategoryTile.circleLineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
            
            // Status text in center
            Text(statusText)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: Constants.CategoryTile.circleSize - 20)
        }
        .frame(width: Constants.CategoryTile.circleSize, height: Constants.CategoryTile.circleSize)
    }
    
    private var progressColor: Color {
        if isCompleted {
            return AppStyle.Color.green
        } else {
            return AppStyle.Color.green
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
            .font(AppStyle.Font.categorySelectionChipFont)
            .foregroundColor(.white)
            .frame(width: width)
            .padding(.vertical, verticalPadding)
            .background(chipBackground)
            .overlay(chipOverlay)
    }
    
    private var chipBackground: some View {
        RoundedRectangle(cornerRadius: Constants.ProgressBar.cornerRadius)
            .fill(getBackgroundColor())
    }
    
    private func getBackgroundColor() -> Color {
        if isCompleted {
            return AppStyle.Color.green
        } else {
            return AppStyle.Color.exerciseCardBackground
        }
    }
    
    private var chipOverlay: some View {
        Group {
            if text != "Completed" {
                RoundedRectangle(cornerRadius: Constants.ProgressBar.cornerRadius)
                    .stroke(Constants.secondaryTextColor, lineWidth: 1)
            }
        }
    }
}

private struct ProgressBar: View {
    let progress: Double
    let totalWidth: CGFloat
    
    private let fillColor = AppStyle.Color.green
    private let trackColor = Constants.secondaryTextColor
    
    var body: some View {
        ZStack(alignment: .leading) {
            trackView
            progressView
        }
        .frame(width: totalWidth, height: Constants.ProgressBar.height)
    }
    
    private var trackView: some View {
        Capsule()
            .strokeBorder(trackColor, lineWidth: Constants.ProgressBar.strokeWidth)
            .background(
                Capsule()
                    .fill(AppStyle.Color.exerciseCardBackground)
            )
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
