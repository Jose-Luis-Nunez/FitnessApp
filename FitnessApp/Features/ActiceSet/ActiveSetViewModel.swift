import Foundation
import Combine

class ActiveSetViewModel: ObservableObject {
    @Published var currentExercise: Exercise?
    @Published var setProgress: [SetProgress] = []
    @Published var pendingSetIndex: Int? = nil
    @Published var currentSet: Int = 0
    @Published var activeSetIndex: Int = 0
    @Published var isSetInProgress: Bool = false
    @Published var isLastSetCompleted: Bool = false
    @Published var timerSeconds: Int = 0
    
    private let timerService: TimerService
    
    @Published var isEditing: Bool = false
    @Published var repsInput: String = ""
    @Published var weightInput: String = ""
    @Published var editMode: SetEditingMode = .less
    @Published var quickDoneModeActive: Bool = false
    
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
        
        timerService.$timerSeconds
            .sink { [weak self] value in
                self?.timerSeconds = value
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    func startSet(for exercise: Exercise) {
        currentExercise = exercise
        currentSet = 0
        activeSetIndex = 0
        setProgress = (0..<exercise.sets).map { _ in
            SetProgress(status: .notStarted, currentReps: exercise.reps, weight: exercise.weight)
        }
        isSetInProgress = true
        isLastSetCompleted = false
        timerService.resetAndStartTimer()
    }
    
    func startNextSet() {
        guard let exercise = currentExercise, currentSet < exercise.sets else { return }
        activeSetIndex = currentSet
        isSetInProgress = true
        timerService.resetAndStartTimer()
    }
    
    func completeCurrentSet() {
        guard let exercise = currentExercise else { return }
        
        let progress = SetProgress(
            status: .completedDone,
            currentReps: exercise.reps,
            weight: exercise.weight
        )
        if setProgress.count <= currentSet {
            setProgress.append(progress)
        } else {
            setProgress[currentSet] = progress
        }
        
        if currentSet + 1 >= exercise.sets {
            isLastSetCompleted = true
        }
        
        currentSet += 1
        isSetInProgress = false
        timerService.stopTimer()
    }
    
    func updateCurrentReps(_ newReps: Int, _ newWeight: Int) {
        guard let exercise = currentExercise else { return }
        
        let status: SetStatus = newReps < exercise.reps
        ? .completedLess
        : .completedMore
        let progress = SetProgress(
            status: status,
            currentReps: newReps,
            weight: newWeight
        )
        if setProgress.count <= currentSet {
            setProgress.append(progress)
        } else {
            setProgress[currentSet] = progress
        }
        
        if currentSet + 1 >= exercise.sets {
            isSetInProgress = false
            isLastSetCompleted = true
        } else {
            isSetInProgress = false
        }
        
        currentSet += 1
    }
    
    func finishExercise() {
        currentExercise = nil
        setProgress = []
        currentSet = 0
        isSetInProgress = false
        isLastSetCompleted = false
        quickDoneModeActive = false
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
    
    func startQuickDone(for exercise: Exercise) {
        currentExercise = exercise
        currentSet = 0
        setProgress = (0..<exercise.sets).map { _ in
            SetProgress(status: .notStarted, currentReps: exercise.reps, weight: exercise.weight)
        }
        quickDoneModeActive = true
        isSetInProgress = false
        isLastSetCompleted = false
    }
    
    func processQuickDone(at index: Int) {
        guard let exercise = currentExercise, index < setProgress.count else { return }
        if setProgress[index].status == .completedDone {
            return
        }
        print("Processing set \(index) at time \(Date()) with trigger source: ViewModel")
        setProgress[index] = SetProgress(status: .completedDone, currentReps: exercise.reps, weight: exercise.weight)
        if setProgress.allSatisfy({ $0.status == .completedDone }) {
            isLastSetCompleted = true
        }
    }
    
    func formatTime(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

