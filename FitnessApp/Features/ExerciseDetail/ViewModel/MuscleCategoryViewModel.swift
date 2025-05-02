import Foundation

enum SetAction {
    case none, done, less, more
}

struct SetProgress {
    let action: SetAction
    let currentReps: Int
    let weight: Int
}

class MuscleCategoryViewModel: ObservableObject {
    @Published var exercises: [Exercise]
    @Published var showResetConfirmation: Bool = false
    
    let group: MuscleCategoryGroup
    let formViewModel: ExerciseFormViewModel
    let activeSetViewModel: ActiveSetViewModel
    
    init(group: MuscleCategoryGroup) {
        self.group = group
        self.exercises = []
        self.formViewModel = ExerciseFormViewModel()
        self.activeSetViewModel = ActiveSetViewModel()
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
    
    func add(_ exercise: Exercise, atTop: Bool) {
        if atTop {
            exercises.insert(exercise, at: 0)
        } else {
            exercises.append(exercise)
        }
    }
    
    func updateExercise(_ updatedExercise: Exercise) {
        if let index = exercises.firstIndex(where: { $0.id == updatedExercise.id }) {
            exercises[index] = updatedExercise
            if activeSetViewModel.currentExercise?.id == updatedExercise.id {
                activeSetViewModel.currentExercise = updatedExercise
            }
        }
    }
    
    func startSet(for exercise: Exercise) {
        activeSetViewModel.startSet(for: exercise)
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
        }
    }
    
    func startTimer() {
        activeSetViewModel.startTimer()
    }
    
    func stopTimer() {
        activeSetViewModel.stopTimer()
    }
    
    func updateCurrentReps(_ newReps: Int, _ newWeight: Int) {
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
    }
}
