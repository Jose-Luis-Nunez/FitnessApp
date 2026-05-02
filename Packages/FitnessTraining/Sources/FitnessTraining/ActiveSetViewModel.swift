import Foundation
import Observation
import FitnessCore
import FitnessUI

// MARK: - State Structs

public struct SetTrackingState {
    public var currentExercise: Exercise?
    public var setProgress: [SetProgress] = []
    public var currentSet: Int = 0
    public var activeSetIndex: Int = 0
    public var isSetInProgress: Bool = false
    public var isLastSetCompleted: Bool = false
    public var category: MuscleCategoryGroup?
    public var originalCategory: MuscleCategoryGroup?

    public init() {}

    public var allSetsCompleted: Bool {
        setProgress.allSatisfy { $0.status != .notStarted && $0.status != .inProgress }
    }

    public mutating func reset() {
        currentExercise = nil
        setProgress = []
        currentSet = 0
        activeSetIndex = 0
        isSetInProgress = false
        isLastSetCompleted = false
        category = nil
        originalCategory = nil
    }
}

public struct SetEditingState {
    public var isEditing: Bool = false
    public var repsInput: String = ""
    public var weightInput: String = ""
    public var editMode: SetEditingMode = .less
    public var pendingEditIndex: Int? = nil
    public var didEditCompleteSet: Bool = false
    public var didJustEditSet: Bool = false

    public init() {}

    public mutating func reset() {
        isEditing = false
        repsInput = ""
        weightInput = ""
        editMode = .less
        pendingEditIndex = nil
        didEditCompleteSet = false
        didJustEditSet = false
    }
}

public struct QuickDoneState {
    public var isActive: Bool = false
    public var allCompleted: Bool = false

    public init() {}

    public mutating func reset() {
        isActive = false
        allCompleted = false
    }
}

// MARK: - ViewModel

@Observable
@MainActor
public final class ActiveSetViewModel {
    public private(set) var tracking = SetTrackingState()
    public private(set) var editing = SetEditingState()
    public private(set) var quickDone = QuickDoneState()
    public var pendingSetIndex: Int? = nil
    /// Elapsed timer seconds, delegated to `TimerService`. SwiftUI observes
    /// this through `@Observable` property forwarding — no polling needed.
    public var timerSeconds: Int { timerService.timerSeconds }

    /// Identifies this in-flight training session for downstream consumers.
    /// Refreshed on every fresh `startSet(for:category:)` call so that
    /// re-starting the same exercise (after Beenden / Cancel / Reset) yields a
    /// new identity — the per-session feedback record then correctly inserts
    /// instead of overwriting a previous session's record. Re-focusing an
    /// already-active session in `TrainingCoordinator.startTraining` does
    /// **not** call `startSet` again, so the id is preserved across
    /// focus-switches.
    public private(set) var sessionId: UUID = UUID()

    private let timerService: TimerService

    // MARK: - Bridged accessors (keep callers working)

    public var currentExercise: Exercise? {
        get { tracking.currentExercise }
        set { tracking.currentExercise = newValue }
    }

    public var setProgress: [SetProgress] {
        get { tracking.setProgress }
        set { tracking.setProgress = newValue }
    }

    public var currentSet: Int {
        get { tracking.currentSet }
        set { tracking.currentSet = newValue }
    }

    public var activeSetIndex: Int {
        get { tracking.activeSetIndex }
        set { tracking.activeSetIndex = newValue }
    }

    public var isSetInProgress: Bool {
        get { tracking.isSetInProgress }
        set { tracking.isSetInProgress = newValue }
    }

    public var isLastSetCompleted: Bool {
        get { tracking.isLastSetCompleted }
        set { tracking.isLastSetCompleted = newValue }
    }

    public var category: MuscleCategoryGroup? {
        get { tracking.category }
        set { tracking.category = newValue }
    }

    public var originalCategory: MuscleCategoryGroup? {
        get { tracking.originalCategory }
        set { tracking.originalCategory = newValue }
    }

    public var isEditing: Bool {
        get { editing.isEditing }
        set { editing.isEditing = newValue }
    }

    public var repsInput: String {
        get { editing.repsInput }
        set { editing.repsInput = newValue }
    }

    public var weightInput: String {
        get { editing.weightInput }
        set { editing.weightInput = newValue }
    }

    public var editMode: SetEditingMode {
        get { editing.editMode }
        set { editing.editMode = newValue }
    }

    public var pendingEditIndex: Int? {
        get { editing.pendingEditIndex }
        set { editing.pendingEditIndex = newValue }
    }

    public var didEditCompleteSet: Bool {
        get { editing.didEditCompleteSet }
        set { editing.didEditCompleteSet = newValue }
    }

    public var didJustEditSet: Bool {
        get { editing.didJustEditSet }
        set { editing.didJustEditSet = newValue }
    }

    public var quickDoneModeActive: Bool {
        get { quickDone.isActive }
        set { quickDone.isActive = newValue }
    }

    public var quickDoneAllCompleted: Bool {
        get { quickDone.allCompleted }
        set { quickDone.allCompleted = newValue }
    }

    public var isInputValid: Bool {
        guard let newReps = Int(editing.repsInput),
              let exercise = tracking.currentExercise else { return false }
        guard let newWeight = WeightFormatter.parse(editing.weightInput) else { return false }

        switch editing.editMode {
        case .less:
            return newReps < exercise.reps || newWeight < exercise.weight
        case .more:
            return newReps > exercise.reps || newWeight > exercise.weight
        case .edit:
            return true
        }
    }

    public init() {
        self.timerService = TimerService()
    }

    public init(timerService: TimerService) {
        self.timerService = timerService
    }

    // MARK: - Set Lifecycle

    public func startSet(for exercise: Exercise, category: MuscleCategoryGroup) {
        // Fresh session = fresh identity. Feedback persisted during this
        // session is bound to this id, so re-starting the same exercise gets
        // its own feedback record instead of overwriting a previous one.
        sessionId = UUID()

        tracking.currentExercise = exercise
        tracking.category = category
        if tracking.originalCategory == nil {
            tracking.originalCategory = category
        }

        tracking.currentSet = 0
        tracking.activeSetIndex = 0
        tracking.setProgress = (0..<exercise.sets).map { _ in
            SetProgress(status: .notStarted, currentReps: exercise.reps, weight: exercise.weight)
        }
        tracking.isSetInProgress = true
        tracking.isLastSetCompleted = false
        quickDone.allCompleted = false
        editing.didEditCompleteSet = false
        editing.didJustEditSet = false
        timerService.resetAndStartTimer()
    }

    public func startNextSet() {
        guard let exercise = tracking.currentExercise, tracking.currentSet < exercise.sets else { return }
        tracking.activeSetIndex = tracking.currentSet
        tracking.isSetInProgress = true
        editing.didJustEditSet = false
        timerService.resetAndStartTimer()
    }

    public func completeCurrentSet() {
        guard let exercise = tracking.currentExercise else { return }
        guard tracking.currentSet < exercise.sets else { return }
        guard tracking.currentSet < tracking.setProgress.count else { return }

        tracking.setProgress[tracking.currentSet] = SetProgress(
            status: .completedDone,
            currentReps: exercise.reps,
            weight: exercise.weight
        )

        tracking.currentSet += 1

        if tracking.currentSet >= exercise.sets {
            tracking.isLastSetCompleted = true
            timerService.timerSeconds = 0
        }

        tracking.isSetInProgress = false
        timerService.stopTimer()
    }

    public func updateCurrentReps(_ newReps: Int, _ newWeight: Double) {
        guard let exercise = tracking.currentExercise else { return }

        let indexToUpdate = editing.pendingEditIndex ?? tracking.currentSet
        let status: SetStatus = newReps < exercise.reps ? .completedLess : .completedMore
        let progress = SetProgress(status: status, currentReps: newReps, weight: newWeight)

        if tracking.setProgress.count <= indexToUpdate {
            tracking.setProgress.append(progress)
        } else {
            tracking.setProgress[indexToUpdate] = progress
        }

        let isEditingOlderSet = editing.pendingEditIndex != nil
            && editing.pendingEditIndex != tracking.activeSetIndex
        let shouldAdvance = !isEditingOlderSet

        if shouldAdvance {
            tracking.currentSet += 1
            if tracking.currentSet >= exercise.sets {
                tracking.isLastSetCompleted = true
            }
        }

        tracking.isSetInProgress = false
        editing.didJustEditSet = isEditingOlderSet || editing.pendingEditIndex != nil
        editing.pendingEditIndex = nil

        if tracking.allSetsCompleted {
            tracking.isLastSetCompleted = true
            editing.didEditCompleteSet = true
            timerService.stopTimer()
            timerService.timerSeconds = 0
        }
    }

    public func finishExercise() {
        tracking.reset()
        editing.reset()
        quickDone.reset()
    }

    public func resetProgress() {
        tracking.reset()
        quickDone.allCompleted = false
        editing.didJustEditSet = false
    }

    // MARK: - Timer

    public func startTimer() {
        timerService.startTimer()
    }

    public func stopTimer() {
        timerService.stopTimer()
    }

    public func resetEditingState() {
        editing.repsInput = ""
        editing.weightInput = ""
    }

    public func formatTime(seconds: Int) -> String {
        seconds.formattedAsTimer
    }

    // MARK: - Quick Done

    public func startQuickDone(for exercise: Exercise, category: MuscleCategoryGroup) {
        // Quick-done is also a fresh session start — same rationale as in
        // `startSet`: feedback recorded after this call belongs to a new
        // session and must not collide with a previous one's record.
        sessionId = UUID()

        tracking.currentExercise = exercise
        tracking.category = category
        tracking.currentSet = 0
        tracking.setProgress = (0..<exercise.sets).map { _ in
            SetProgress(status: .completedDone, currentReps: exercise.reps, weight: exercise.weight)
        }
        quickDone.isActive = false
        quickDone.allCompleted = true
        tracking.isSetInProgress = true
        tracking.isLastSetCompleted = true
        editing.didEditCompleteSet = false
        editing.didJustEditSet = false

        timerService.resetAndStartTimer()
        timerService.stopTimer()
        timerService.timerSeconds = 0
    }

    public func processQuickDone(at index: Int) {
        guard let exercise = tracking.currentExercise, index < tracking.setProgress.count else { return }
        if tracking.setProgress[index].status == .completedDone { return }

        tracking.setProgress[index] = SetProgress(
            status: .completedDone,
            currentReps: exercise.reps,
            weight: exercise.weight
        )

        if tracking.allSetsCompleted {
            tracking.isLastSetCompleted = true
            quickDone.allCompleted = true
            timerService.stopTimer()
            timerService.timerSeconds = 0
        }
    }

    public func completeAllQuickDone() {
        guard let exercise = tracking.currentExercise else { return }
        for index in 0..<tracking.setProgress.count {
            let status = tracking.setProgress[index].status
            if status == .notStarted || status == .inProgress {
                tracking.setProgress[index] = SetProgress(
                    status: .completedDone,
                    currentReps: exercise.reps,
                    weight: exercise.weight
                )
            }
        }
        quickDone.allCompleted = tracking.allSetsCompleted
        tracking.isLastSetCompleted = quickDone.allCompleted

        if quickDone.allCompleted {
            timerService.stopTimer()
            timerService.timerSeconds = 0
        }
    }

    // MARK: - Editing

    public func startEditingSet(index: Int, mode: SetEditingMode) {
        let reps = tracking.setProgress[index].currentReps
        let weight = tracking.setProgress[index].weight

        editing.repsInput = String(reps)
        editing.weightInput = WeightFormatter.format(weight)
        editing.pendingEditIndex = index
        editing.editMode = mode
        editing.isEditing = true
    }

    public func cancelActiveSet() {
        tracking.reset()
        quickDone.reset()
        editing.didEditCompleteSet = false
        editing.didJustEditSet = false

        timerService.stopTimer()
        timerService.timerSeconds = 0
    }
}
