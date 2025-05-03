import Foundation

class ActiveSetViewModel: ObservableObject {
    @Published var currentExercise: Exercise?
    @Published var setProgress: [SetProgress] = []
    @Published var currentSet: Int = 0
    @Published var isSetInProgress: Bool = false
    @Published var isLastSetCompleted: Bool = false
    
    private let timerService: TimerService
    var timerSeconds: Int {
        timerService.timerSeconds
    }
    
    @Published var isEditing: Bool = false
    @Published var repsInput: String = ""
    @Published var weightInput: String = ""
    @Published var editMode: SetEditingMode = .less
    
    var isInputValid: Bool {
        guard let newReps = Int(repsInput),
              let newWeight = Int(weightInput),
              let exercise = currentExercise else { return false }
        
        let currentReps = exercise.reps
        let currentWeight = exercise.weight
        
        switch editMode {
        case .less:
            return newReps < currentReps || newWeight < currentWeight
        case .more:
            return newReps > currentReps || newWeight > currentWeight
        }
    }

    init() {
        self.timerService = TimerService()
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
        guard let exercise = currentExercise else { return }
        
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
    }
    
    func updateCurrentReps(_ newReps: Int, _ newWeight: Int) {
        guard let exercise = currentExercise else { return }
        
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
    }
    
    func finishExercise() {
        currentExercise = nil
        setProgress = []
        currentSet = 0
        isSetInProgress = false
        isLastSetCompleted = false
    }
    
    func resetProgress() {
        currentExercise = nil
        setProgress = []
        currentSet = 0
        isSetInProgress = false
        isLastSetCompleted = false
    }

    func startTimer() {
        timerService.startTimer()
    }

    func stopTimer() {
        timerService.stopTimer()
    }

    func resetEditingState() {
        repsInput = ""
        weightInput = ""
    }

    func startEditing(mode: SetEditingMode) {
        guard let exercise = currentExercise else { return }
        isEditing = true
        editMode = mode
        repsInput = String(exercise.reps)
        weightInput = String(exercise.weight)
    }
}
