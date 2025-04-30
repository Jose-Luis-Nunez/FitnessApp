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
    @Published var currentExercise: Exercise?
    @Published var setProgress: [SetProgress] = []
    @Published var currentSet: Int = 0
    @Published var isSetInProgress: Bool = false
    @Published var isLastSetCompleted: Bool = false
    @Published var showForm: Bool = false
    @Published var isEditingCurrentReps: Bool = false
    @Published var currentRepsInput: String = ""
    @Published var weightInput: String = ""
    @Published var currentRepsEditMode: MuscleCategoryView.RepsEditMode = .less
    @Published var showResetConfirmation: Bool = false
    @Published var timerSeconds: Int = 0
    @Published var name: String = ""
    @Published var weight: String = ""
    @Published var reps: String = ""
    @Published var sets: String = ""
    @Published var seat: String = ""

    let group: MuscleCategoryGroup
    private let storageService: ExerciseStorageService
    private var timer: Timer?

    var isInputValid: Bool {
        guard let newReps = Int(currentRepsInput),
              let newWeight = Int(weightInput),
              let currentExercise = currentExercise else { return false }
        
        let currentReps = currentExercise.reps
        let currentWeight = currentExercise.weight
        
        switch currentRepsEditMode {
        case .less:
            return newReps < currentReps || newWeight < currentWeight
        case .more:
            return newReps > currentReps || newWeight > currentWeight
        }
    }

    init(group: MuscleCategoryGroup) {
        self.group = group
        self.storageService = ExerciseStorageService()
        self.exercises = storageService.load(for: group)
        self.currentExercise = nil
        self.setProgress = []
        self.currentSet = 0
        self.isSetInProgress = false
        self.isLastSetCompleted = false
    }

    func startSet(for exercise: Exercise) {
        currentExercise = exercise
        currentSet = 0
        setProgress = []
        isSetInProgress = true
        isLastSetCompleted = false
    }
    
    func startNextSet() {
        if currentExercise != nil {
            isSetInProgress = true
        }
    }
    
    func completeCurrentSet() {
        guard let exercise = currentExercise,
              let index = exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        
        let progress = SetProgress(
            action: .done,
            currentReps: exercise.reps,
            weight: exercise.weight
        )
        if setProgress.count <= currentSet {
            setProgress.append(progress)
        } else {
            setProgress[currentSet] = progress
        }
        
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
    
    func updateCurrentReps(_ newReps: Int, _ newWeight: Int) {
        guard let exercise = currentExercise,
              let _ = exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        
        let action: SetAction = newReps < exercise.reps ? .less : .more
        let progress = SetProgress(
            action: action,
            currentReps: newReps,
            weight: newWeight
        )
        if setProgress.count <= currentSet {
            setProgress.append(progress)
        } else {
            setProgress[currentSet] = progress
        }
        
        currentSet += 1
        
        if currentSet >= exercise.sets {
            isSetInProgress = false
            isLastSetCompleted = true
        } else {
            isSetInProgress = false
        }
        
        storageService.save(exercises, for: group)
    }
    
    func finishExercise() {
        guard let exercise = currentExercise,
              let index = exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        
        var updatedExercise = exercise
        updatedExercise.isCompleted = true
        exercises[index] = updatedExercise
        currentExercise = nil
        setProgress = []
        currentSet = 0
        isSetInProgress = false
        isLastSetCompleted = false
        storageService.save(exercises, for: group)
    }
    
    func resetProgress() {
        currentExercise = nil
        setProgress = []
        currentSet = 0
        isSetInProgress = false
        isLastSetCompleted = false
        
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
        timerSeconds = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.timerSeconds += 1
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
        timerSeconds = 0
    }

    func clearForm() {
        name = ""
        weight = ""
        reps = ""
        sets = ""
        seat = ""
        showForm = false
    }

    func toggleForm() {
        showForm.toggle()
    }

    func resetEditingState() {
        currentRepsInput = ""
        weightInput = ""
    }
}
