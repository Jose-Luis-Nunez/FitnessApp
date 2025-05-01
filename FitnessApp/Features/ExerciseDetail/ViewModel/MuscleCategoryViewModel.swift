import Foundation

enum SetAction {
    case none, done, less, more
}

struct SetProgress {
    let action: SetAction
    let currentReps: Int
    let weight: Int
}

final class MuscleCategoryViewModel: ObservableObject {
    @Published var exercises: [Exercise]
    @Published var showResetConfirmation: Bool = false

    let group: MuscleCategoryGroup
    private let storageService: ExerciseStorageService
    let formViewModel: ExerciseFormViewModel
    let activeSetViewModel: ActiveSetViewModel

    init(group: MuscleCategoryGroup) {
        self.group = group
        self.storageService = ExerciseStorageService()
        self.formViewModel = ExerciseFormViewModel()
        self.activeSetViewModel = ActiveSetViewModel()
        self.exercises = storageService.load(for: group)
    }

    var currentExercise: Exercise? {
        activeSetViewModel.currentExercise
    }

    var setProgress: [SetProgress] {
        activeSetViewModel.setProgress
    }

    var currentSet: Int {
        activeSetViewModel.currentSet
    }

    var isSetInProgress: Bool {
        activeSetViewModel.isSetInProgress
    }

    var isLastSetCompleted: Bool {
        activeSetViewModel.isLastSetCompleted
    }

    var timerSeconds: Int {
        activeSetViewModel.timerSeconds
    }

    func startSet(for exercise: Exercise) {
        activeSetViewModel.startSet(for: exercise)
    }
    
    func startNextSet() {
        activeSetViewModel.startNextSet()
    }
    
    func completeCurrentSet() {
        activeSetViewModel.completeCurrentSet()
        if let exercise = activeSetViewModel.currentExercise,
           let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            exercises[index] = exercise
            storageService.save(exercises, for: group)
        }
    }
    
    func updateCurrentReps(_ newReps: Int, _ newWeight: Int) {
        activeSetViewModel.updateCurrentReps(newReps, newWeight)
        if let exercise = activeSetViewModel.currentExercise,
           let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            exercises[index] = exercise
            storageService.save(exercises, for: group)
        }
    }
    
    func finishExercise() {
        guard let exercise = activeSetViewModel.currentExercise,
              let index = exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        
        var updatedExercise = exercise
        updatedExercise.isCompleted = true
        exercises[index] = updatedExercise
        activeSetViewModel.finishExercise()
        storageService.save(exercises, for: group)
    }
    
    func resetProgress() {
        activeSetViewModel.resetProgress()
        exercises = exercises.map { exercise in
            var updatedExercise = exercise
            updatedExercise.isCompleted = false
            return updatedExercise
        }
        storageService.save(exercises, for: group)
    }
    
    func add(_ exercise: Exercise) {
        exercises.append(exercise)
        storageService.save(exercises, for: group)
    }
    
    func updateExercise(_ exercise: Exercise) {
        if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            exercises[index] = exercise
            storageService.save(exercises, for: group)
        }
    }
    
    var hasActiveExercise: Bool {
        !exercises.filter { !$0.isCompleted }.isEmpty
    }

    func startTimer() {
        activeSetViewModel.startTimer()
    }

    func stopTimer() {
        activeSetViewModel.stopTimer()
    }
}
