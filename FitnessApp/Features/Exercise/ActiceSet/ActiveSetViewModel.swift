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
    
    @Published var quickDoneAllCompleted: Bool = false
    @Published var pendingEditIndex: Int? = nil
    @Published var didEditCompleteSet: Bool = false
    
    @Published var didJustEditSet: Bool = false
    @Published var pendingEditMode: SetEditingMode? = nil
    var category: MuscleCategoryGroup?
    var originalStartSource: TrainingStartSource = .categoryView
    var originalCategory: MuscleCategoryGroup?
    
    // Callback to notify parent coordinator of critical state changes
    var onCoordinatorUpdateNeeded: (() -> Void)?

    var isInputValid: Bool {
        guard let newReps = Int(repsInput),
              let exercise = currentExercise else { return false }
        // Accept comma as decimal separator (e.g., "54,5")
        guard let newWeight = WeightFormatter.parse(weightInput) else { return false }
        
        let currentReps = exercise.reps
        let currentWeight = exercise.weight
        
        switch editMode {
        case .less:
            return newReps < currentReps || newWeight < currentWeight
        case .more:
            return newReps > currentReps || newWeight > currentWeight
        case .edit:
            return true
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
    
    func startSet(for exercise: Exercise, category: MuscleCategoryGroup, startSource: TrainingStartSource = .categoryView) {
        currentExercise = exercise
        self.category = category
        
        // Only set original values if this is a new training (not a restart)
        if originalCategory == nil {
            originalStartSource = startSource
            originalCategory = category
        }
        
        currentSet = 0
        activeSetIndex = 0
        setProgress = (0..<exercise.sets).map { _ in
            SetProgress(status: .notStarted, currentReps: exercise.reps, weight: exercise.weight)
        }
        isSetInProgress = true
        isLastSetCompleted = false
        quickDoneAllCompleted = false
        didEditCompleteSet = false
        didJustEditSet = false
        timerService.resetAndStartTimer()
    }
    
    func startNextSet() {
        guard let exercise = currentExercise, currentSet < exercise.sets else { return }
        activeSetIndex = currentSet
        isSetInProgress = true
        didJustEditSet = false
        timerService.resetAndStartTimer()
    }
    
    func completeCurrentSet() {
        guard let exercise = currentExercise else { return }
        
        // Prevent completing sets beyond the defined number
        guard currentSet < exercise.sets else {
            return
        }
        
        guard currentSet < setProgress.count else {
            return
        }
        
        let progress = SetProgress(
            status: .completedDone,
            currentReps: exercise.reps,
            weight: exercise.weight
        )
        
        setProgress[currentSet] = progress
        
        currentSet += 1
        
        if currentSet >= exercise.sets {
            isLastSetCompleted = true
        }
        
        isSetInProgress = false
        timerService.stopTimer()
        
        // Reset timer to 00:00 when exercise is completed
        if currentSet >= exercise.sets {
            timerSeconds = 0
        }
    }
    
    func updateCurrentReps(_ newReps: Int, _ newWeight: Double) {
        guard let exercise = currentExercise else { 
            return 
        }
        
        let indexToUpdate: Int
        if let editIndex = pendingEditIndex {
            indexToUpdate = editIndex
        } else {
            indexToUpdate = currentSet
        }
        
        let status: SetStatus = newReps < exercise.reps ? .completedLess : .completedMore
        let progress = SetProgress(
            status: status,
            currentReps: newReps,
            weight: newWeight
        )
        
        if setProgress.count <= indexToUpdate {
            setProgress.append(progress)
        } else {
            setProgress[indexToUpdate] = progress
        }
        
        if pendingEditIndex == nil {
            // Only increment currentSet if we're completing a new set, not editing an old one
            currentSet += 1
            if currentSet >= exercise.sets {
                isLastSetCompleted = true
            }
            isSetInProgress = false
            didJustEditSet = false
        } else {
            // We're editing an existing set - BUT if it's the active set, increment currentSet like "Done"
            if pendingEditIndex == activeSetIndex {
                currentSet += 1
                if currentSet >= exercise.sets {
                    isLastSetCompleted = true
                }
            }
            isSetInProgress = false
            didJustEditSet = true
        }
        
        pendingEditIndex = nil
        
        if setProgress.allSatisfy({ $0.status != .notStarted && $0.status != .inProgress }) {
            isSetInProgress = false
            isLastSetCompleted = true
            didEditCompleteSet = true
            
            // Reset timer to 00:00 when all sets are completed via Less/More
            timerService.stopTimer()
            timerSeconds = 0
        }
    }
    
    func finishExercise() {
        currentExercise = nil
        setProgress = []
        currentSet = 0
        isSetInProgress = false
        isLastSetCompleted = false
        quickDoneModeActive = false
        quickDoneAllCompleted = false
        didEditCompleteSet = false
        didJustEditSet = false
        category = nil
        originalCategory = nil
        originalStartSource = .categoryView
    }
    
    func resetProgress() {
        currentExercise = nil
        setProgress = []
        currentSet = 0
        isSetInProgress = false
        isLastSetCompleted = false
        quickDoneAllCompleted = false
        didJustEditSet = false
        category = nil
        originalCategory = nil
        originalStartSource = .categoryView
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
        // Display decimals with comma to match picker options
        weightInput = exercise.weight == floor(exercise.weight)
            ? String(Int(exercise.weight))
            : String(exercise.weight).replacingOccurrences(of: ".", with: ",")
    }
    
    func startQuickDone(for exercise: Exercise, category: MuscleCategoryGroup) {
        // Set up the exercise and category
        currentExercise = exercise
        self.category = category
        currentSet = 0 // Start from first set for timer display
        setProgress = (0..<exercise.sets).map { _ in
            SetProgress(status: .completedDone, currentReps: exercise.reps, weight: exercise.weight)
        }
        // Set up state for timer display with cancel functionality
        quickDoneModeActive = false
        quickDoneAllCompleted = true
        isSetInProgress = true  // Enable timer display
        isLastSetCompleted = true
        didEditCompleteSet = false
        didJustEditSet = false
        
        // Start timer so user can see time and cancel if needed
        timerService.resetAndStartTimer()
        
        // Since all sets are already completed in quick done, reset timer to 00:00
        timerService.stopTimer()
        timerSeconds = 0
    }
    
    func processQuickDone(at index: Int) {
        guard let exercise = currentExercise, index < setProgress.count else { return }
        if setProgress[index].status == .completedDone {
            return
        }
        setProgress[index] = SetProgress(status: .completedDone, currentReps: exercise.reps, weight: exercise.weight)
        
        if setProgress.allSatisfy({ $0.status != .notStarted && $0.status != .inProgress }) {
            isLastSetCompleted = true
            quickDoneAllCompleted = true
            
            // Reset timer to 00:00 when all sets are completed in quick done mode
            timerService.stopTimer()
            timerSeconds = 0
        }
    }
    
    func completeAllQuickDone() {
        guard let exercise = currentExercise else { return }
        for index in 0..<setProgress.count {
            if setProgress[index].status == .notStarted || setProgress[index].status == .inProgress {
                setProgress[index] = SetProgress(status: .completedDone, currentReps: exercise.reps, weight: exercise.weight)
            }
        }
        quickDoneAllCompleted = setProgress.allSatisfy { $0.status != .notStarted && $0.status != .inProgress }
        isLastSetCompleted = quickDoneAllCompleted
        
        // Reset timer to 00:00 when all sets are completed via "All Done" button
        if quickDoneAllCompleted {
            timerService.stopTimer()
            timerSeconds = 0
        }
    }
    
    func formatTime(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    func startEditingSet(index: Int, mode: SetEditingMode) {
        pendingEditIndex = index
        pendingEditMode = mode
        isEditing = true
        editMode = mode
        
        let reps = setProgress[index].currentReps
        let weight = setProgress[index].weight
        repsInput = String(reps)
        // Display decimals with comma to match picker options
        weightInput = weight == floor(weight)
            ? String(Int(weight))
            : String(weight).replacingOccurrences(of: ".", with: ",")
        
        // AGGRESSIVE UI REFRESH - Force SwiftUI to update NOW
        objectWillChange.send()

        // CRITICAL: Also notify parent coordinator for state propagation
        onCoordinatorUpdateNeeded?()

        DispatchQueue.main.async {
            self.objectWillChange.send()
            // Double-notify coordinator
            self.onCoordinatorUpdateNeeded?()

            // Additional refresh after short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                self.objectWillChange.send()
                self.onCoordinatorUpdateNeeded?()
            }
        }
    }
    
    func handleAppForeground() {
        if isSetInProgress {
            timerService.updateTimer()
            timerService.startTimer()
        }
    }
    
    func cancelActiveSet() {
        guard let exercise = currentExercise else { return }
        
        currentExercise = nil
        currentSet = 0
        activeSetIndex = 0
        setProgress = []
        isSetInProgress = false
        isLastSetCompleted = false
        quickDoneModeActive = false
        quickDoneAllCompleted = false
        didEditCompleteSet = false
        didJustEditSet = false
        category = nil
        originalStartSource = .categoryView  // Reset to default
        originalCategory = nil  // Reset to nil
        
        timerService.stopTimer()
        timerSeconds = 0
        
        objectWillChange.send()
    }
}
