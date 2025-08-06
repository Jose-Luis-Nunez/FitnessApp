import Foundation

class MuscleCategoryViewModel: ObservableObject {
    @Published var exercises: [Exercise]
    @Published var showResetConfirmation: Bool = false
    
    let group: MuscleCategoryGroup
    let formViewModel: ExerciseFormViewModel
    let activeSetViewModel: ActiveSetViewModel
    private let storageService: ExerciseStorageService
    private let analyticsViewModel: AnalyticsViewModel
    private let workoutStorageService = WorkoutStorageService.shared
    
    init(group: MuscleCategoryGroup) {
        self.group = group
        self.formViewModel = ExerciseFormViewModel()
        self.storageService = ExerciseStorageService()
        self.analyticsViewModel = AnalyticsViewModel()
        
        // Load workout-specific exercises
        if let currentWorkout = WorkoutStorageService.shared.currentWorkout {
            self.exercises = storageService.loadForWorkout(workoutId: currentWorkout.id, category: group)
        } else {
            self.exercises = storageService.load(for: group)
        }
        if let existing = SessionTrainingCache.shared.activeSetVMs[group] {
            self.activeSetViewModel = existing
        } else {
            let newVM = ActiveSetViewModel()
            self.activeSetViewModel = newVM
            SessionTrainingCache.shared.activeSetVMs[group] = newVM
        }
    }
    
    var currentExercise: Exercise? {
        activeSetViewModel.currentExercise
    }
    
    var currentSet: Int {
        activeSetViewModel.currentSet
    }
    
    var setProgress: [SetProgress] {
        activeSetViewModel.setProgress
    }
    
    var timerSeconds: Int {
        activeSetViewModel.timerSeconds
    }
    
    var isSetInProgress: Bool {
        activeSetViewModel.isSetInProgress
    }
    
    var isLastSetCompleted: Bool {
        activeSetViewModel.isLastSetCompleted
    }
    
    var hasActiveExercise: Bool {
        exercises.contains { !$0.isCompleted }
    }
    
    var totalExercises: Int {
        exercises.count
    }
    
    var activeExercises: Int {
        exercises.filter { !$0.isCompleted }.count
    }
    
    func add(_ exercise: Exercise, atTop: Bool) {
        if atTop {
            exercises.insert(exercise, at: 0)
        } else {
            exercises.append(exercise)
        }
        saveExercises()
    }
    
    func updateExercise(_ updatedExercise: Exercise) {
        if let index = exercises.firstIndex(where: { $0.id == updatedExercise.id }) {
            exercises[index] = updatedExercise
            if activeSetViewModel.currentExercise?.id == updatedExercise.id {
                activeSetViewModel.currentExercise = updatedExercise
            }
            saveExercises()
        }
    }
    
    func startSet(for exercise: Exercise) {
        activeSetViewModel.startSet(for: exercise, category: group) 
    }
    
    func startNextSet() {
        activeSetViewModel.startNextSet()
    }
    
    func completeCurrentSet() {
        activeSetViewModel.completeCurrentSet()
    }
    
    func finishExercise() {
        if let currentExercise = activeSetViewModel.currentExercise,
           let index = exercises.firstIndex(where: { $0.id == currentExercise.id }) {
            var updatedExercise = currentExercise
            updatedExercise.isCompleted = true
            exercises[index] = updatedExercise
            activeSetViewModel.finishExercise()
            saveExercises()
        }
    }
    
    func startTimer() {
        activeSetViewModel.startTimer()
    }
    
    func stopTimer() {
        activeSetViewModel.stopTimer()
    }
    
    func updateCurrentReps(_ newReps: Int, _ newWeight: Double) {
        activeSetViewModel.updateCurrentReps(newReps, newWeight)
    }
    
    func resetProgress() {
        exercises = exercises.map { exercise in
            var updated = exercise
            updated.isCompleted = false
            return updated
        }
        activeSetViewModel.resetProgress()
        stopTimer()
        saveExercises()
    }
    
    private func saveExercises() {
        if storageService.hasUserId {
            if let currentWorkout = workoutStorageService.currentWorkout {
                storageService.saveForWorkout(exercises, workoutId: currentWorkout.id, category: group)
            } else {
                storageService.save(exercises, for: group)
            }
        } else {
            print("No userId available, skipping save")
        }
    }
    
    func saveAnalytics() {
        guard let exercise = activeSetViewModel.currentExercise else {
            print("No exercise to save for analytics")
            return
        }
        analyticsViewModel.saveAnalytics(
            exerciseId: exercise.id,
            setProgress: activeSetViewModel.setProgress
        )
    }
    
    func resetExercise(_ exercise: Exercise) {
        var updatedExercise = exercise
        updatedExercise.isCompleted = false
        updatedExercise.sets = exercise.sets
        updatedExercise.reps = exercise.reps
        updatedExercise.weight = exercise.weight
        updateExercise(updatedExercise)
        print("Reset done for exercise: \(exercise.name)")
    }
}
