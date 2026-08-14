import Foundation
import Observation
import FitnessCore
import FitnessUI

// MARK: - State Structs

/// The last reps/weight a user dialed in for a Less or More adjustment during
/// the current session. Used to pre-fill the picker on the next Less/More so
/// repeated adjustments don't have to be re-entered from the exercise default.
public struct SetAdjustment: Sendable, Equatable {
    public var reps: Int
    public var weight: Double

    public init(reps: Int, weight: Double) {
        self.reps = reps
        self.weight = weight
    }
}

public struct SetTrackingState {
    public var currentExercise: Exercise?
    public var setProgress: [SetProgress] = []
    public var currentSet: Int = 0
    public var activeSetIndex: Int = 0
    public var isSetInProgress: Bool = false
    public var isLastSetCompleted: Bool = false
    public var category: MuscleCategoryGroup?
    public var originalCategory: MuscleCategoryGroup?

    /// Session-scoped memory of the most recent Less / More adjustment, kept
    /// separately per mode so each pre-fills the picker with its own last value.
    public var lastLessAdjustment: SetAdjustment? = nil
    public var lastMoreAdjustment: SetAdjustment? = nil
    public var lastLessAdjustmentBySide: [ExerciseSide: SetAdjustment] = [:]
    public var lastMoreAdjustmentBySide: [ExerciseSide: SetAdjustment] = [:]

    public init() {}

    public var allSetsCompleted: Bool {
        !setProgress.isEmpty && setProgress.allSatisfy { $0.status != .notStarted && $0.status != .inProgress }
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
        lastLessAdjustment = nil
        lastMoreAdjustment = nil
        lastLessAdjustmentBySide = [:]
        lastMoreAdjustmentBySide = [:]
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
    public var allCompleted: Bool = false

    public init() {}

    public mutating func reset() {
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
        case .edit, .achievement:
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
        tracking.setProgress = exercise.trainingSteps.map { step in
            SetProgress(
                status: .notStarted,
                currentReps: exercise.reps,
                weight: exercise.weight,
                side: step.side,
                logicalSetIndex: step.logicalSetIndex
            )
        }
        tracking.lastLessAdjustment = nil
        tracking.lastMoreAdjustment = nil
        tracking.lastLessAdjustmentBySide = [:]
        tracking.lastMoreAdjustmentBySide = [:]
        tracking.isSetInProgress = true
        tracking.isLastSetCompleted = false
        quickDone.allCompleted = false
        editing.didEditCompleteSet = false
        editing.didJustEditSet = false
        timerService.resetAndStartTimer()
    }

    public func startNextSet() {
        guard let exercise = tracking.currentExercise,
              tracking.currentSet < exercise.trainingSteps.count,
              !tracking.isLastSetCompleted else { return }
        tracking.activeSetIndex = tracking.currentSet
        tracking.isSetInProgress = true
        editing.didJustEditSet = false
        timerService.resetAndStartTimer()
    }

    public func completeCurrentSet() {
        guard let exercise = tracking.currentExercise else { return }
        guard tracking.currentSet < exercise.trainingSteps.count else { return }
        guard tracking.currentSet < tracking.setProgress.count else { return }

        let currentProgress = tracking.setProgress[tracking.currentSet]
        tracking.setProgress[tracking.currentSet] = currentProgress.transitioned(
            to: .completedDone,
            currentReps: exercise.reps,
            weight: exercise.weight
        )

        tracking.currentSet += 1

        if tracking.currentSet >= exercise.trainingSteps.count {
            tracking.isLastSetCompleted = true
            timerService.timerSeconds = 0
        }

        tracking.isSetInProgress = false
        timerService.stopTimer()
    }

    public func updateCurrentReps(_ newReps: Int, _ newWeight: Double) {
        guard let exercise = tracking.currentExercise else { return }
        guard tracking.currentSet < exercise.trainingSteps.count || editing.pendingEditIndex != nil else { return }

        let indexToUpdate = editing.pendingEditIndex ?? tracking.currentSet
        let status: SetStatus
        if editing.isEditing, case .less = editing.editMode {
            // Less is an explicit user choice. A weight-only reduction leaves
            // reps unchanged, so deriving the status from reps would otherwise
            // incorrectly save it as More and lose the Less pre-fill memory.
            status = .completedLess
        } else if editing.isEditing, case .achievement = editing.editMode {
            status = achievementStatus(
                reps: newReps,
                weight: newWeight,
                targetReps: exercise.reps,
                targetWeight: exercise.weight
            )
        } else {
            status = newReps < exercise.reps ? .completedLess : .completedMore
        }
        guard indexToUpdate < tracking.setProgress.count else { return }
        let previousProgress = tracking.setProgress[indexToUpdate]
        let progress = previousProgress.transitioned(
            to: status,
            currentReps: newReps,
            weight: newWeight
        )

        // Remember this adjustment per mode so the next Less/More opens pre-filled.
        switch status {
        case .completedLess:
            remember(
                SetAdjustment(reps: newReps, weight: newWeight),
                mode: .less,
                side: previousProgress.side
            )
        case .completedMore:
            remember(
                SetAdjustment(reps: newReps, weight: newWeight),
                mode: .more,
                side: previousProgress.side
            )
        default: break
        }

        tracking.setProgress[indexToUpdate] = progress

        let isEditingOlderSet = editing.pendingEditIndex != nil
            && editing.pendingEditIndex != tracking.activeSetIndex
        let shouldAdvance = !isEditingOlderSet

        if shouldAdvance && tracking.currentSet < exercise.trainingSteps.count {
            tracking.currentSet += 1
            if tracking.currentSet >= exercise.trainingSteps.count {
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
        editing.reset()
        quickDone.reset()
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
        tracking.setProgress = exercise.trainingSteps.map { step in
            SetProgress(
                status: .completedDone,
                currentReps: exercise.reps,
                weight: exercise.weight,
                side: step.side,
                logicalSetIndex: step.logicalSetIndex
            )
        }
        tracking.lastLessAdjustment = nil
        tracking.lastMoreAdjustment = nil
        tracking.lastLessAdjustmentBySide = [:]
        tracking.lastMoreAdjustmentBySide = [:]
        quickDone.allCompleted = true
        tracking.isSetInProgress = false
        tracking.isLastSetCompleted = true
        editing.didEditCompleteSet = false
        editing.didJustEditSet = false

        timerService.resetAndStartTimer()
        timerService.stopTimer()
        timerService.timerSeconds = 0
    }

    // MARK: - Editing

    /// Opens result entry for the one execution step that is currently active.
    /// Future steps stay inert, while completed steps continue to use `.edit`
    /// through the existing `startEditingSet` path.
    func startRecordingAchievement(index: Int) {
        guard tracking.setProgress.indices.contains(index),
              tracking.isSetInProgress,
              !tracking.isLastSetCompleted,
              index == tracking.activeSetIndex,
              index == tracking.currentSet else {
            return
        }

        let status = tracking.setProgress[index].status
        guard status == .notStarted || status == .inProgress else {
            return
        }

        startEditingSet(index: index, mode: .achievement)
    }

    public func startEditingSet(index: Int, mode: SetEditingMode) {
        let progress = tracking.setProgress[index]

        // For a fresh set, pre-fill with the last adjustment of this mode so the
        // user doesn't re-enter the same Less/More value set after set. Editing
        // an already-completed set keeps showing that set's real values.
        let remembered = progress.status == .notStarted
            ? rememberedAdjustment(for: mode, side: progress.side)
            : nil

        editing.repsInput = String(remembered?.reps ?? progress.currentReps)
        // Editing state remains locale-neutral; the presentation layer formats
        // the numeric value with its environment locale.
        let weight = remembered?.weight ?? progress.weight
        editing.weightInput = weight == floor(weight) ? String(Int(weight)) : String(weight)
        editing.pendingEditIndex = index
        editing.editMode = mode
        editing.isEditing = true
    }

    /// The remembered adjustment to pre-fill for a given mode, or `nil` when the
    /// mode has no session memory (`.edit`, or nothing recorded yet).
    private func rememberedAdjustment(
        for mode: SetEditingMode,
        side: ExerciseSide?
    ) -> SetAdjustment? {
        switch mode {
        case .less:
            side.flatMap { tracking.lastLessAdjustmentBySide[$0] }
                ?? tracking.lastLessAdjustment
        case .more:
            side.flatMap { tracking.lastMoreAdjustmentBySide[$0] }
                ?? tracking.lastMoreAdjustment
        case .edit, .achievement: nil
        }
    }

    private func remember(
        _ adjustment: SetAdjustment,
        mode: SetEditingMode,
        side: ExerciseSide?
    ) {
        switch (mode, side) {
        case (.less, .some(let side)):
            tracking.lastLessAdjustmentBySide[side] = adjustment
        case (.more, .some(let side)):
            tracking.lastMoreAdjustmentBySide[side] = adjustment
        case (.less, .none):
            tracking.lastLessAdjustment = adjustment
        case (.more, .none):
            tracking.lastMoreAdjustment = adjustment
        case (.edit, _), (.achievement, _):
            break
        }
    }

    private func achievementStatus(
        reps: Int,
        weight: Double,
        targetReps: Int,
        targetWeight: Double
    ) -> SetStatus {
        if reps < targetReps { return .completedLess }
        if reps > targetReps { return .completedMore }
        if weight < targetWeight { return .completedLess }
        if weight > targetWeight { return .completedMore }
        return .completedDone
    }

    public func cancelActiveSet() {
        tracking.reset()
        editing.reset()
        quickDone.reset()

        timerService.stopTimer()
        timerService.timerSeconds = 0
    }
}
