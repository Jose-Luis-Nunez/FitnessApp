import SwiftUI
import Combine

// MARK: - Training Callbacks Protocol
struct TrainingCallbacks {
    let onStart: () -> Void
    let onCompleteSet: () -> Void
    let onQuickDone: () -> Void
    let onCompleteAllQuickDone: () -> Void
    let onCategoryReset: () -> Void
    let onEditLess: () -> Void
    let onEditMore: () -> Void
    let onFinish: () -> Void
    let onAddExercise: () -> Void
    let onResetAllExercises: () -> Void
}

// MARK: - Training Coordinator
class TrainingCoordinator: ObservableObject {
    @Published var activeSetViewModel: ActiveSetViewModel
    @Published var currentExercise: Exercise?
    @Published var isTrainingActive: Bool = false
    
    private let exerciseRepository: ExerciseStorageService
    private let analyticsViewModel = AnalyticsViewModel()
    private let findCategory: (Exercise) -> MuscleCategoryGroup?
    private let onExerciseUpdate: (Exercise, MuscleCategoryGroup) -> Void
    private let onExerciseReset: (Exercise, MuscleCategoryGroup) -> Void
    private let onAddExercise: () -> Void
    private let onResetAllExercises: () -> Void
    
    private var cancellables = Set<AnyCancellable>()
    
    init(
        findCategory: @escaping (Exercise) -> MuscleCategoryGroup?,
        onExerciseUpdate: @escaping (Exercise, MuscleCategoryGroup) -> Void,
        onExerciseReset: @escaping (Exercise, MuscleCategoryGroup) -> Void,
        onAddExercise: @escaping () -> Void = {},
        onResetAllExercises: @escaping () -> Void = {},
        activeSetViewModel: ActiveSetViewModel? = nil
    ) {
        if let providedViewModel = activeSetViewModel {
            self.activeSetViewModel = providedViewModel
        } else {
            self.activeSetViewModel = ActiveSetViewModel()
        }
        self.exerciseRepository = ExerciseStorageService()
        self.findCategory = findCategory
        self.onExerciseUpdate = onExerciseUpdate
        self.onExerciseReset = onExerciseReset
        self.onAddExercise = onAddExercise
        self.onResetAllExercises = onResetAllExercises
    }
    
    // MARK: - Training Actions
    
    func startTraining(for exercise: Exercise) {
        guard let category = findCategory(exercise) else { return }
        
        // Get or create the appropriate ActiveSetViewModel for this category from SessionTrainingCache
        let categoryActiveSetVM: ActiveSetViewModel
        if let existing = SessionTrainingCache.shared.activeSetVMs[category] {
            categoryActiveSetVM = existing
        } else {
            let newVM = ActiveSetViewModel()
            SessionTrainingCache.shared.activeSetVMs[category] = newVM
            categoryActiveSetVM = newVM
        }
        
        // Update our reference to point to the correct category VM
        activeSetViewModel = categoryActiveSetVM
        setupActiveSetViewModelObserver()
        
        // Always start the first set immediately when training begins
        activeSetViewModel.startSet(for: exercise, category: category)
        
        // Update published properties
        currentExercise = exercise
        isTrainingActive = true
    }
    
    func completeSet() {
        guard let exercise = activeSetViewModel.currentExercise else { 
            return 
        }
        
        // Prevent completing sets beyond the defined number OR if already completed
        guard activeSetViewModel.currentSet < exercise.sets && !activeSetViewModel.isLastSetCompleted else {
            return
        }
        
        activeSetViewModel.stopTimer()
        
        // Check if this is the last set BEFORE completing
        let isLastSet = (activeSetViewModel.currentSet + 1) >= exercise.sets
        
        activeSetViewModel.completeCurrentSet()
        
        // Force UI refresh after completing set
        objectWillChange.send()
        
        // Auto-start next set only if not the last set
        if !isLastSet {
            activeSetViewModel.startNextSet()
        }
    }
    
    func handleQuickDone() {
        guard let exercise = activeSetViewModel.currentExercise,
              let category = findCategory(exercise) else { return }
        
        activeSetViewModel.startQuickDone(for: exercise, category: category)
    }
    

    
    func resetExercise() {
        activeSetViewModel.stopTimer()
        
        guard let exercise = activeSetViewModel.currentExercise,
              let category = findCategory(exercise) else { return }
        
        onExerciseReset(exercise, category)
        activeSetViewModel.resetProgress()
        
        // Update published properties
        currentExercise = nil
        isTrainingActive = false
    }
    
    func editLess() {
        activeSetViewModel.stopTimer()
        
        // Use the active set index instead of current set for editing
        let editIndex = activeSetViewModel.activeSetIndex
        
        // Bounds check to prevent crash
        guard editIndex >= 0 && editIndex < activeSetViewModel.setProgress.count else {
            return
        }
        
        activeSetViewModel.startEditingSet(index: editIndex, mode: .less)
    }
    
    func editMore() {
        activeSetViewModel.stopTimer()
        
        // Use the active set index instead of current set for editing
        let editIndex = activeSetViewModel.activeSetIndex
        
        // Bounds check to prevent crash
        guard editIndex >= 0 && editIndex < activeSetViewModel.setProgress.count else {
            return
        }
        
        activeSetViewModel.startEditingSet(index: editIndex, mode: .more)
    }
    
    func finishExercise() {
        activeSetViewModel.stopTimer()
        
        guard let exercise = activeSetViewModel.currentExercise,
              let category = findCategory(exercise) else { return }
        
        // Save analytics before finishing the exercise
        saveAnalytics()
        
        if activeSetViewModel.isLastSetCompleted {
            var updatedExercise = exercise
            updatedExercise.isCompleted = true
            onExerciseUpdate(updatedExercise, category)
        }
        
        activeSetViewModel.finishExercise()
        activeSetViewModel.quickDoneModeActive = false
        
        // Update published properties
        currentExercise = nil
        isTrainingActive = false
    }
    
    // MARK: - BottomActionBar Integration
    
    func createBottomActionBarViewModel(exercises: [Exercise], hasActiveExercise: Bool) -> BottomActionBarViewModel {
        return BottomActionBarViewModel(
            isSetInProgress: activeSetViewModel.isSetInProgress,
            currentSet: activeSetViewModel.currentSet,
            currentExercise: activeSetViewModel.currentExercise,
            hasActiveExercise: hasActiveExercise,
            exercises: exercises,
            isLastSetCompleted: activeSetViewModel.isLastSetCompleted,
            quickDoneModeActive: activeSetViewModel.quickDoneModeActive,
            quickDoneAllCompleted: activeSetViewModel.quickDoneAllCompleted,
            didEditCompleteSet: activeSetViewModel.didEditCompleteSet,
            didJustEditSet: activeSetViewModel.didJustEditSet,
            showResetAllExercisesButton: false
        )
    }
    
    func createTrainingCallbacks() -> TrainingCallbacks {
        return TrainingCallbacks(
            onStart: { [weak self] in
                guard let self = self else { return }
                guard let exercise = self.activeSetViewModel.currentExercise else { return }
                
                // Prevent starting sets beyond the defined number
                guard self.activeSetViewModel.currentSet < exercise.sets else {
                    return
                }
                
                // This is for starting the next set, not initial training
                self.activeSetViewModel.startNextSet()
            },
            onCompleteSet: { [weak self] in
                self?.completeSet()
            },
            onQuickDone: { [weak self] in
                self?.handleQuickDone()
            },
            onCompleteAllQuickDone: { [weak self] in
                // All Done button removed - no action needed
            },
            onCategoryReset: { [weak self] in
                self?.resetExercise()
            },
            onEditLess: { [weak self] in
                self?.editLess()
            },
            onEditMore: { [weak self] in
                self?.editMore()
            },
            onFinish: { [weak self] in
                self?.finishExercise()
            },
            onAddExercise: { [weak self] in
                self?.onAddExercise()
            },
            onResetAllExercises: { [weak self] in
                self?.onResetAllExercises()
            }
        )
    }
    
    // MARK: - Analytics
    
    private func saveAnalytics() {
        guard let exercise = activeSetViewModel.currentExercise else {
            print("No exercise to save for analytics")
            return
        }
        analyticsViewModel.saveAnalytics(
            exerciseId: exercise.id,
            setProgress: activeSetViewModel.setProgress
        )
    }
    
    // MARK: - Current Exercise Management
    
    func setCurrentExercise(_ exercise: Exercise?) {
        currentExercise = exercise
        isTrainingActive = exercise != nil
        activeSetViewModel.currentExercise = exercise
    }
    
    // MARK: - Private Helpers
    
    private func setupActiveSetViewModelObserver() {
        // Clear existing cancellables for this specific observer
        cancellables.removeAll()
        
        // Observe changes to currentExercise in the activeSetViewModel
        activeSetViewModel.$currentExercise
            .sink { [weak self] newExercise in
                DispatchQueue.main.async {
                    self?.currentExercise = newExercise
                    self?.isTrainingActive = newExercise != nil
                }
            }
            .store(in: &cancellables)
    }
    
    private func findNextAvailableExercise() -> Exercise? {
        // This should be implemented by the parent view
        // For now, return nil
        return nil
    }
}
