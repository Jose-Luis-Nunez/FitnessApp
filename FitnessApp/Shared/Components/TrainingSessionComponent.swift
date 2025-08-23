import SwiftUI

// MARK: - Training Session Component
struct TrainingSessionComponent: View {
    @ObservedObject var coordinator: TrainingCoordinator
    let onEdit: ((Exercise) -> Void)?
    let onReset: ((Exercise) -> Void)?
    let analyticsViewModel: AnalyticsViewModel
    
    init(
        coordinator: TrainingCoordinator,
        onEdit: ((Exercise) -> Void)? = nil,
        onReset: ((Exercise) -> Void)? = nil,
        analyticsViewModel: AnalyticsViewModel = AnalyticsViewModel()
    ) {
        self.coordinator = coordinator
        self.onEdit = onEdit
        self.onReset = onReset
        self.analyticsViewModel = analyticsViewModel
    }
    
    var body: some View {
        if let exercise = coordinator.currentExercise {
            VStack(spacing: 16) {
                ActiveSetView(
                    sets: exercise.sets,
                    exercise: exercise,
                    setProgress: $coordinator.activeSetViewModel.setProgress,
                    viewModel: coordinator.activeSetViewModel
                )
                .onAppear {
                    if coordinator.activeSetViewModel.isSetInProgress {
                        coordinator.activeSetViewModel.startTimer()
                    }
                }
                
                TimerView(viewModel: coordinator.activeSetViewModel)
            }
            .padding(.vertical, 0)
        }
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
