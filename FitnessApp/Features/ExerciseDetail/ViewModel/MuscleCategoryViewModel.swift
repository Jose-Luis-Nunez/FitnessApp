import Foundation

class MuscleCategoryViewModel: ObservableObject {
    @Published var exercises: [Exercise]
    @Published var currentExercise: Exercise?
    @Published var currentSet: Int = 0
    @Published var isSetInProgress: Bool = false
    @Published var isLastSetCompleted: Bool = false
    private let group: MuscleCategoryGroup
    private let storageService: ExerciseStorageService
    
    var hasActiveExercise: Bool {
        exercises.contains { !$0.isCompleted }
    }

    init(group: MuscleCategoryGroup) {
        self.group = group
        self.storageService = ExerciseStorageService() // Kein Parameter
        self.exercises = storageService.load(for: group) // Parameter 'for: group'
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

    func startSet(for exercise: Exercise) {
        if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            currentExercise = exercises[index]
            isSetInProgress = true
            isLastSetCompleted = false
        }
    }

    func completeCurrentSet() {
        guard let exercise = currentExercise,
              let index = exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        
        currentSet += 1
        
        if currentSet >= exercise.sets {
            isSetInProgress = false
            isLastSetCompleted = true
        } else {
            isSetInProgress = false
        }
        
        exercises[index] = exercise
        storageService.save(exercises, for: group)
    }

    func finishExercise() {
        guard let exercise = currentExercise,
              let index = exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        
        exercises[index].isCompleted = true
        currentExercise = nil
        currentSet = 0
        isSetInProgress = false
        isLastSetCompleted = false
        storageService.save(exercises, for: group)
    }

    func updateCurrentReps(_ newReps: Int) {
        guard let exercise = currentExercise,
              let index = exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        
        exercises[index].currentReps = newReps
        storageService.save(exercises, for: group)
    }

    func resetProgress() {
        for index in exercises.indices {
            exercises[index].isCompleted = false
        }
        currentExercise = nil
        currentSet = 0
        isSetInProgress = false
        isLastSetCompleted = false
        storageService.save(exercises, for: group)
    }
}
