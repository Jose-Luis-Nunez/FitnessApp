import SwiftUI
import Observation
import FitnessCore
import FitnessAnalytics
import FitnessUI
import Factory

// MARK: - Training Callbacks Protocol

public struct TrainingCallbacks {
    public let onStart: () -> Void
    public let onCompleteSet: () -> Void
    public let onQuickDone: () -> Void
    public let onCategoryReset: () -> Void
    public let onEditLess: () -> Void
    public let onEditMore: () -> Void
    public let onFinish: () -> Void
    public let onAddExercise: () -> Void
    public let onResetAllExercises: () -> Void
    public let onOpenFeedback: () -> Void

    public init(
        onStart: @escaping () -> Void,
        onCompleteSet: @escaping () -> Void,
        onQuickDone: @escaping () -> Void,
        onCategoryReset: @escaping () -> Void,
        onEditLess: @escaping () -> Void,
        onEditMore: @escaping () -> Void,
        onFinish: @escaping () -> Void,
        onAddExercise: @escaping () -> Void,
        onResetAllExercises: @escaping () -> Void,
        onOpenFeedback: @escaping () -> Void = {}
    ) {
        self.onStart = onStart
        self.onCompleteSet = onCompleteSet
        self.onQuickDone = onQuickDone
        self.onCategoryReset = onCategoryReset
        self.onEditLess = onEditLess
        self.onEditMore = onEditMore
        self.onFinish = onFinish
        self.onAddExercise = onAddExercise
        self.onResetAllExercises = onResetAllExercises
        self.onOpenFeedback = onOpenFeedback
    }
}

// MARK: - Training Coordinator

@Observable
@MainActor
public final class TrainingCoordinator {
    public var activeSessions: [Exercise.ID: ActiveSetViewModel] = [:]
    public var activeExercises: [Exercise.ID: Exercise] = [:]
    public var focusedExerciseId: Exercise.ID?
    public var lastCompletedExercise: Exercise?

    /// Controls the presentation of the post-exercise feedback sheet. Flipped
    /// by `openFeedback()` / `closeFeedback()` and observed by views via
    /// `@Bindable`.
    public var isFeedbackSheetPresented: Bool = false

    /// In-memory store for the currently focused exercise's feedback draft.
    /// Lives on the coordinator so any view that already has the coordinator
    /// (e.g. `FeedbackSheetComponent`, `TrainingActionBarComponent`) can read
    /// it without an extra environment slot. Drafts are never persisted.
    public let draftStore = ExerciseFeedbackDraftStore()

    /// Backwards-compatible computed property: returns the focused session's VM,
    /// falling back to a shared idle instance so callers never deal with nil.
    public var activeSetViewModel: ActiveSetViewModel {
        focusedSession ?? _idleViewModel
    }

    public var focusedSession: ActiveSetViewModel? {
        guard let id = focusedExerciseId else { return nil }
        return activeSessions[id]
    }

    public var currentExercise: Exercise? {
        guard let id = focusedExerciseId else { return nil }
        return activeExercises[id]
    }

    public var isTrainingActive: Bool {
        focusedExerciseId != nil && activeSessions[focusedExerciseId!] != nil
    }

    public var hasActiveSessions: Bool {
        !activeSessions.isEmpty
    }

    public func session(for exerciseId: Exercise.ID) -> ActiveSetViewModel? {
        activeSessions[exerciseId]
    }

    public func isExerciseInProgress(_ exerciseId: Exercise.ID) -> Bool {
        activeSessions[exerciseId] != nil
    }

    /// Returns the in-flight session id for `exerciseId` if one is active.
    /// Used by feedback consumers (`FeedbackEntryIconResolver`,
    /// `FeedbackViewModel`) to bind a feedback record to the specific
    /// training session it was captured in. Returns `nil` when the exercise
    /// is not currently active — outside an active session there is no
    /// feedback to bind, by design.
    public func currentSessionId(for exerciseId: Exercise.ID) -> UUID? {
        activeSessions[exerciseId]?.sessionId
    }

    private let _idleViewModel = ActiveSetViewModel()

    public let analyticsViewModel: AnalyticsViewModel
    let findCategory: (Exercise) -> MuscleCategoryGroup?
    private let onExerciseUpdate: @MainActor (Exercise, MuscleCategoryGroup) -> Void
    private let onExerciseReset: @MainActor (Exercise, MuscleCategoryGroup) -> Void
    private var _onAddExercise: @MainActor () -> Void
    private var _onResetAllExercises: @MainActor () -> Void

    @ObservationIgnored @Injected(\.startTrainingUseCase)
    private var startTrainingUseCase: StartTrainingUseCase
    @ObservationIgnored @Injected(\.completeSetUseCase)
    private var completeSetUseCase: CompleteSetUseCase
    @ObservationIgnored @Injected(\.finishExerciseUseCase)
    private var finishExerciseUseCase: FinishExerciseUseCase
    @ObservationIgnored @Injected(\.cancelTrainingUseCase)
    private var cancelTrainingUseCase: CancelTrainingUseCase
    @ObservationIgnored @Injected(\.resetExerciseUseCase)
    private var resetExerciseUseCase: ResetExerciseUseCase

    private let sessionFactory: @MainActor () -> ActiveSetViewModel

    public init(
        findCategory: @escaping @MainActor (Exercise) -> MuscleCategoryGroup?,
        onExerciseUpdate: @escaping @MainActor (Exercise, MuscleCategoryGroup) -> Void,
        onExerciseReset: @escaping @MainActor (Exercise, MuscleCategoryGroup) -> Void,
        onAddExercise: @escaping @MainActor () -> Void = {},
        onResetAllExercises: @escaping @MainActor () -> Void = {},
        analyticsViewModel: AnalyticsViewModel = AnalyticsViewModel(),
        sessionFactory: @escaping @MainActor () -> ActiveSetViewModel = { ActiveSetViewModel() }
    ) {
        self.analyticsViewModel = analyticsViewModel
        self.findCategory = findCategory
        self.onExerciseUpdate = onExerciseUpdate
        self.onExerciseReset = onExerciseReset
        self._onAddExercise = onAddExercise
        self._onResetAllExercises = onResetAllExercises
        self.sessionFactory = sessionFactory
    }

    /// Replaces the add-exercise callback. Only the currently visible view
    /// should call this; the coordinator itself never mutates it internally.
    public func setOnAddExercise(_ handler: @escaping @MainActor () -> Void) {
        _onAddExercise = handler
    }

    /// Replaces the reset-all callback.
    public func setOnResetAllExercises(_ handler: @escaping @MainActor () -> Void) {
        _onResetAllExercises = handler
    }

    /// Centralised setter for `focusedExerciseId`. **All** internal writes go
    /// through here so that the draft store's lifecycle hook
    /// (`handleActiveExerciseChange(to:)`) fires consistently — switching to
    /// or clearing the focused exercise must always discard a stale draft of
    /// the previous exercise.
    private func setFocusedExerciseId(_ newValue: Exercise.ID?) {
        focusedExerciseId = newValue
        draftStore.handleActiveExerciseChange(to: newValue)
    }

    // MARK: - Training Actions

    public func startTraining(for exercise: Exercise) {
        guard let category = findCategory(exercise) else { return }

        if let existingVM = activeSessions[exercise.id] {
            setFocusedExerciseId(exercise.id)
            return
        }

        let vm = sessionFactory()

        // Result intentionally unused: multi-session architecture gives each
        // exercise its own VM, so .switchedFrom / finishPreviousTraining is never
        // triggered from the coordinator (always nil). The use case still supports
        // it for single-session callers.
        _ = startTrainingUseCase.execute(
            exercise: exercise,
            category: category,
            activeSetViewModel: vm,
            finishPreviousTraining: nil
        )

        activeSessions[exercise.id] = vm
        activeExercises[exercise.id] = exercise
        setFocusedExerciseId(exercise.id)
    }

    public func completeSet() {
        completeSetUseCase.execute(activeSetViewModel: activeSetViewModel)
    }

    public func handleQuickDone() {
        let vm = activeSetViewModel
        guard let exercise = vm.currentExercise,
              let category = findCategory(exercise) else { return }

        vm.startQuickDone(for: exercise, category: category)
    }

    public func cancelTraining() {
        guard let id = focusedExerciseId else { return }
        cancelTrainingUseCase.execute(activeSetViewModel: activeSetViewModel)
        activeSessions.removeValue(forKey: id)
        activeExercises.removeValue(forKey: id)
        setFocusedExerciseId(nil)
    }

    public func cancelTraining(for exerciseId: Exercise.ID) {
        guard let vm = activeSessions[exerciseId] else { return }
        cancelTrainingUseCase.execute(activeSetViewModel: vm)
        activeSessions.removeValue(forKey: exerciseId)
        activeExercises.removeValue(forKey: exerciseId)
        if focusedExerciseId == exerciseId {
            setFocusedExerciseId(nil)
        }
    }

    public func resetExercise() {
        guard let id = focusedExerciseId else { return }
        resetExerciseUseCase.execute(
            activeSetViewModel: activeSetViewModel,
            findCategory: findCategory,
            onExerciseReset: onExerciseReset
        )
        activeSessions.removeValue(forKey: id)
        activeExercises.removeValue(forKey: id)
        setFocusedExerciseId(nil)
    }

    public func editLess() {
        let vm = activeSetViewModel
        vm.stopTimer()

        let editIndex = vm.activeSetIndex

        guard editIndex >= 0 && editIndex < vm.setProgress.count else {
            return
        }

        vm.startEditingSet(index: editIndex, mode: .less)
    }

    public func editMore() {
        let vm = activeSetViewModel
        vm.stopTimer()

        let editIndex = vm.activeSetIndex

        guard editIndex >= 0 && editIndex < vm.setProgress.count else {
            return
        }

        vm.startEditingSet(index: editIndex, mode: .more)
    }

    public func finishExercise() {
        guard let id = focusedExerciseId else { return }
        let vm = activeSetViewModel
        if let completed = finishExerciseUseCase.execute(
            activeSetViewModel: vm,
            analyticsViewModel: analyticsViewModel,
            findCategory: findCategory,
            onExerciseUpdate: onExerciseUpdate
        ) {
            lastCompletedExercise = completed
        }
        activeSessions.removeValue(forKey: id)
        activeExercises.removeValue(forKey: id)
        setFocusedExerciseId(nil)
    }

    public func finishExercise(for exerciseId: Exercise.ID) {
        guard let vm = activeSessions[exerciseId] else { return }
        if let completed = finishExerciseUseCase.execute(
            activeSetViewModel: vm,
            analyticsViewModel: analyticsViewModel,
            findCategory: findCategory,
            onExerciseUpdate: onExerciseUpdate
        ) {
            lastCompletedExercise = completed
        }
        activeSessions.removeValue(forKey: exerciseId)
        activeExercises.removeValue(forKey: exerciseId)
        if focusedExerciseId == exerciseId {
            setFocusedExerciseId(nil)
        }
    }

    // MARK: - Feedback Sheet

    public func openFeedback() {
        guard currentExercise != nil else { return }
        isFeedbackSheetPresented = true
    }

    public func closeFeedback() {
        isFeedbackSheetPresented = false
    }

    // MARK: - BottomActionBar Integration

    public func createBottomActionBarViewModel(exercises: [Exercise], hasActiveExercise: Bool) -> BottomActionBarViewModel {
        BottomActionBarViewModel(
            isSetInProgress: activeSetViewModel.isSetInProgress,
            currentSet: activeSetViewModel.currentSet,
            currentExercise: activeSetViewModel.currentExercise,
            hasActiveExercise: hasActiveExercise,
            exercises: exercises,
            isLastSetCompleted: activeSetViewModel.isLastSetCompleted,
            quickDoneModeActive: activeSetViewModel.quickDoneModeActive,
            quickDoneAllCompleted: activeSetViewModel.quickDoneAllCompleted,
            didEditCompleteSet: activeSetViewModel.didEditCompleteSet,
            didJustEditSet: activeSetViewModel.didJustEditSet
        )
    }

    public func createTrainingCallbacks() -> TrainingCallbacks {
        TrainingCallbacks(
            onStart: { [weak self] in
                guard let self = self else { return }
                guard let exercise = self.activeSetViewModel.currentExercise else { return }

                guard self.activeSetViewModel.currentSet < exercise.sets else {
                    return
                }

                self.activeSetViewModel.startNextSet()
            },
            onCompleteSet: { [weak self] in
                self?.completeSet()
            },
            onQuickDone: { [weak self] in
                self?.handleQuickDone()
            },
            onCategoryReset: { [weak self] in
                self?.resetExercise()
            },
            onEditLess: { [weak self] in
                self?.editLess()
            },
            onEditMore: { [weak self] in
                self?.editMore()
            },
            onFinish: { [weak self] in
                self?.finishExercise()
            },
            onAddExercise: { [weak self] in
                self?._onAddExercise()
            },
            onResetAllExercises: { [weak self] in
                self?._onResetAllExercises()
            },
            onOpenFeedback: { [weak self] in
                self?.openFeedback()
            }
        )
    }

    // MARK: - Current Exercise Management

    public func setCurrentExercise(_ exercise: Exercise?) {
        if let exercise {
            activeExercises[exercise.id] = exercise
            if activeSessions[exercise.id] == nil {
                let vm = sessionFactory()
                vm.currentExercise = exercise
                activeSessions[exercise.id] = vm
            }
            setFocusedExerciseId(exercise.id)
        } else {
            setFocusedExerciseId(nil)
        }
    }
}
