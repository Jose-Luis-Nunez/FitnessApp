import SwiftUI

// MARK: - Training Session Component
struct TrainingSessionComponent: View {
    @ObservedObject var coordinator: TrainingCoordinator
    let onEdit: ((Exercise) -> Void)?
    let onReset: ((Exercise) -> Void)?
    let onCancel: (() -> Void)?
    let analyticsViewModel: AnalyticsViewModel
    
    // Compact spacing to fit everything within ActiveCardView bounds
    private var dynamicSpacing: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        if screenWidth <= 375 { return 8 }       // iPhone 12 mini: minimal spacing
        else if screenWidth <= 390 { return 10 } // iPhone 12: tight spacing
        else if screenWidth <= 400 { return 12 } // iPhone 16 Pro: compact spacing
        else { return 16 }                       // iPhone Pro Max: comfortable spacing
    }
    init(
        coordinator: TrainingCoordinator,
        onEdit: ((Exercise) -> Void)? = nil,
        onReset: ((Exercise) -> Void)? = nil,
        onCancel: (() -> Void)? = nil,
        analyticsViewModel: AnalyticsViewModel = AnalyticsViewModel()
    ) {
        self.coordinator = coordinator
        self.onEdit = onEdit
        self.onReset = onReset
        self.onCancel = onCancel
        self.analyticsViewModel = analyticsViewModel
    }
    
    var body: some View {
        if let exercise = coordinator.currentExercise {
            VStack(spacing: 16) {
                // Simple container - match ActiveCardView width exactly
                HStack(alignment: .top, spacing: dynamicSpacing) {
                    // Left side: SimpleActiveSetView - takes priority space
                    SimpleActiveSetView(
                        sets: exercise.sets,
                        exercise: exercise,
                        setProgress: $coordinator.activeSetViewModel.setProgress,
                        viewModel: coordinator.activeSetViewModel
                    )
                    .layoutPriority(1) // Higher priority - gets space first
                    .onAppear {
                        if coordinator.activeSetViewModel.isSetInProgress {
                            coordinator.activeSetViewModel.startTimer()
                        }
                    }
                    
                    // Right side: Timer - fills remaining space intelligently
                    CompactTimerComponent(
                        viewModel: coordinator.activeSetViewModel,
                        onCancel: onCancel
                    )
                    .frame(minWidth: 80, maxWidth: 160) // Flexible width with bounds
                }
                .padding(.horizontal, AppStyle.Padding.card) // Only outer padding like ActiveCardView
            }
            .padding(.vertical, 0)
        }
    }
}

// MARK: - Compact Timer Component
struct CompactTimerComponent: View {
    @ObservedObject var viewModel: ActiveSetViewModel
    let onCancel: (() -> Void)?
    
    // Responsive timer font size and width based on screen width
    private var timerFontSize: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        if screenWidth <= 375 { return 15 }      // iPhone 12 mini, SE: readable
        else if screenWidth <= 390 { return 16 } // iPhone 12, 13, 14: readable
        else if screenWidth <= 400 { return 18 } // iPhone 16 Pro: good
        else { return 20 }                       // iPhone Pro Max: large
    }
    
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // Timer display - responsive size based on screen
            Text(viewModel.formatTime(seconds: max(viewModel.timerSeconds, 0)))
                .font(.system(size: timerFontSize, weight: .bold))
                .foregroundColor(AppStyle.Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            
            Spacer()
                .frame(maxHeight: 10) // Spacer begrenzen = Button nach oben
            
            // Cancel button - at bottom
            Button(action: {
                if let onCancel = onCancel {
                    onCancel()
                } else {
                    viewModel.cancelActiveSet()
                }
            }) {
                Text("Cancel")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppStyle.Color.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppStyle.Color.green)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity) // Fill assigned width
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppStyle.Color.greenBlack)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppStyle.Color.greenGlow, lineWidth: 1.5)
                )
        )
    }
}

// MARK: - Training Action Bar Component
struct TrainingActionBarComponent: View {
    @ObservedObject var coordinator: TrainingCoordinator
    let exercises: [Exercise]
    let hasActiveExercise: Bool
    
    init(coordinator: TrainingCoordinator, exercises: [Exercise], hasActiveExercise: Bool) {
        self.coordinator = coordinator
        self.exercises = exercises
        self.hasActiveExercise = hasActiveExercise
    }
    
    private var bottomActionBarViewModel: BottomActionBarViewModel {
        coordinator.createBottomActionBarViewModel(
            exercises: exercises,
            hasActiveExercise: hasActiveExercise
        )
    }
    
    private var trainingCallbacks: TrainingCallbacks {
        let originalCallbacks = coordinator.createTrainingCallbacks()
        
        return TrainingCallbacks(
            onStart: originalCallbacks.onStart,
            onCompleteSet: {
                originalCallbacks.onCompleteSet()
            },
            onQuickDone: originalCallbacks.onQuickDone,
            onCompleteAllQuickDone: originalCallbacks.onCompleteAllQuickDone,
            onCategoryReset: originalCallbacks.onCategoryReset,
            onEditLess: {
                // Only allow editing if currently in progress or completed set exists
                guard coordinator.activeSetViewModel.isSetInProgress || 
                      coordinator.activeSetViewModel.setProgress.count > 0 else {
                    return
                }
                originalCallbacks.onEditLess()
                
                // Force UI update by triggering objectWillChange
                coordinator.objectWillChange.send()
            },
            onEditMore: {
                // Only allow editing if currently in progress or completed set exists
                guard coordinator.activeSetViewModel.isSetInProgress || 
                      coordinator.activeSetViewModel.setProgress.count > 0 else {
                    return
                }
                originalCallbacks.onEditMore()
                
                // Force UI update by triggering objectWillChange
                coordinator.objectWillChange.send()
            },
            onFinish: originalCallbacks.onFinish,
            onAddExercise: originalCallbacks.onAddExercise,
            onResetAllExercises: originalCallbacks.onResetAllExercises
        )
    }
    
    var body: some View {
        // Use the latest activeSetViewModel state for UI decisions
        let currentViewModel = coordinator.activeSetViewModel
        let viewModel = bottomActionBarViewModel
        

        
        if viewModel.shouldShow && !currentViewModel.isEditing {
            BottomActionBarView(
                viewModel: viewModel,
                onStart: trainingCallbacks.onStart,
                onCompleteSet: trainingCallbacks.onCompleteSet,
                onQuickDone: trainingCallbacks.onQuickDone,
                onCompleteAllQuickDone: trainingCallbacks.onCompleteAllQuickDone,
                onCategoryReset: trainingCallbacks.onCategoryReset,
                onEditLess: trainingCallbacks.onEditLess,
                onEditMore: trainingCallbacks.onEditMore,
                onFinish: trainingCallbacks.onFinish,
                onAddExercise: trainingCallbacks.onAddExercise,
                onResetAllExercises: trainingCallbacks.onResetAllExercises
            )
            .zIndex(5)
            .onChange(of: currentViewModel.isLastSetCompleted) { _ in
                // Force UI refresh
            }
            .onChange(of: currentViewModel.isSetInProgress) { _ in
                // Force UI refresh
            }
            .onChange(of: currentViewModel.currentSet) { _ in
                // Force UI refresh
            }
        }
    }
}
