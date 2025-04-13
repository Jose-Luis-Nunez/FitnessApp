import Foundation

@MainActor
final class MuscleCategoryViewModel: ObservableObject {
    @Published private(set) var exercises: [Exercise]
    @Published private(set) var isSetInProgress = false
    @Published private(set) var currentExercise: Exercise?
    private(set) var currentSet = 0
    
    private let group: MuscleCategoryGroup
    private let storage: ExerciseStoring

    var startButtonTitle: String {
        if currentSet == 0 {
            return "Start Sets"
        }
        return "Set \(currentSet + 1) Start"
    }

    init(group: MuscleCategoryGroup, storage: ExerciseStoring = ExerciseStorageService()) {
        self.group = group
        self.storage = storage
        self.exercises = storage.load(for: group)
        self.isSetInProgress = false
        self.currentExercise = nil
        self.currentSet = 0
    }

    func startSet(for exercise: Exercise) {
        if currentExercise?.id != exercise.id {
            currentSet = 0
        }
        currentExercise = exercise
        isSetInProgress = true
    }

    func completeCurrentSet() {
        guard let exercise = currentExercise else { return }
        
        currentSet += 1
        isSetInProgress = false
        
        if currentSet >= exercise.sets {
            if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
                var updated = exercise
                updated.isCompleted = true
                exercises.remove(at: index)
                exercises.append(updated)
                currentExercise = nil
                currentSet = 0
                save()
            }
        }
    }

    func updateCurrentSetReps(_ newReps: Int) {
        completeCurrentSet()
    }

    func updateCurrentReps(_ newReps: Int) {
        if let exercise = currentExercise,
           let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            var updated = exercise
            updated.currentReps = newReps
            exercises[index] = updated
            currentExercise = updated
            save()
        }
    }

    private func completeExercise(_ exercise: Exercise) {
        currentSet = 0
        currentExercise = nil
        if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            var updated = exercise
            updated.isCompleted = true
            
            exercises.remove(at: index)
            exercises.append(updated)
            
            save()
        }
    }

    func add(_ exercise: Exercise) {
        exercises.append(exercise)
        save()
    }

    func delete(at offsets: IndexSet) {
        exercises.remove(atOffsets: offsets)
        save()
    }

    private func save() {
        storage.save(exercises, for: group)
    }
    
    func updateExercise(_ updated: Exercise) {
        guard let index = exercises.firstIndex(where: { $0.id == updated.id }) else { return }
        exercises[index] = updated
        save()
    }

    func resetProgress() {
        isSetInProgress = false
        currentExercise = nil
        currentSet = 0
        for index in exercises.indices {
            exercises[index].isCompleted = false
            exercises[index].currentReps = exercises[index].reps
        }
        save()
    }

}
