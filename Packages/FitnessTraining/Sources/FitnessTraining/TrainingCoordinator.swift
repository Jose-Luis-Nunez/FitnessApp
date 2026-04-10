import SwiftUI
import Observation
import FitnessCore
import FitnessStorage
import FitnessAnalytics
import FitnessUI

// MARK: - Training Callbacks Protocol

public struct TrainingCallbacks {
    public let onStart: () -> Void
    public let onCompleteSet: () -> Void
    public let onQuickDone: () -> Void
    public let onCompleteAllQuickDone: () -> Void
    public let onCategoryReset: () -> Void
    public let onEditLess: () -> Void
    public let onEditMore: () -> Void
    public let onFinish: () -> Void
    public let onAddExercise: () -> Void
    public let onResetAllExercises: () -> Void

    public init(
        onStart: @escaping () -> Void,
        onCompleteSet: @escaping () -> Void,
        onQuickDone: @escaping () -> Void,
        onCompleteAllQuickDone: @escaping () -> Void,
        onCategoryReset: @escaping () -> Void,
        onEditLess: @escaping () -> Void,
        onEditMore: @escaping () -> Void,
        onFinish: @escaping () -> Void,
        onAddExercise: @escaping () -> Void,
        onResetAllExercises: @escaping () -> Void
    ) {
        self.onStart = onStart
        self.onCompleteSet = onCompleteSet
        self.onQuickDone = onQuickDone
        self.onCompleteAllQuickDone = onCompleteAllQuickDone
        self.onCategoryReset = onCategoryReset
        self.onEditLess = onEditLess
        self.onEditMore = onEditMore
        self.onFinish = onFinish
        self.onAddExercise = onAddExercise
        self.onResetAllExercises = onResetAllExercises
    }
}

// MARK: - Training Coordinator

@Observable
@MainActor
public final class TrainingCoordinator {
    public var activeSetViewModel: ActiveSetViewModel
    public var currentExercise: Exercise?
    public var isTrainingActive: Bool = false

    public let analyticsViewModel: AnalyticsViewModel
    private let findCategory: (Exercise) -> MuscleCategoryGroup?
    private let onExerciseUpdate: @MainActor (Exercise, MuscleCategoryGroup) -> Void
    private let onExerciseReset: @MainActor (Exercise, MuscleCategoryGroup) -> Void
    private let onAddExercise: @MainActor () -> Void
    private let onResetAllExercises: @MainActor () -> Void

    private var observationTask: Task<Void, Never>?

    public init(
        findCategory: @escaping @MainActor (Exercise) -> MuscleCategoryGroup?,
        onExerciseUpdate: @escaping @MainActor (Exercise, MuscleCategoryGroup) -> Void,
        onExerciseReset: @escaping @MainActor (Exercise, MuscleCategoryGroup) -> Void,
        onAddExercise: @escaping @MainActor () -> Void = {},
        onResetAllExercises: @escaping @MainActor () -> Void = {},
        activeSetViewModel: ActiveSetViewModel? = nil,
        analyticsViewModel: AnalyticsViewModel = AnalyticsViewModel()
    ) {
        self.analyticsViewModel = analyticsViewModel
        if let providedViewModel = activeSetViewModel {
            self.activeSetViewModel = providedViewModel
        } else {
            self.activeSetViewModel = ActiveSetViewModel()
        }
        self.findCategory = findCategory
        self.onExerciseUpdate = onExerciseUpdate
        self.onExerciseReset = onExerciseReset
        self.onAddExercise = onAddExercise
        self.onResetAllExercises = onResetAllExercises
    }

    // MARK: - Training Actions

    public func startTraining(for exercise: Exercise) {
        guard let category = findCategory(exercise) else {
            return
        }

        activeSetViewModel.onCoordinatorUpdateNeeded = { }

        setupActiveSetViewModelObserver()

        let isSameExercise = activeSetViewModel.currentExercise?.id == exercise.id
        let hasTrainingData = activeSetViewModel.isSetInProgress ||
            activeSetViewModel.isLastSetCompleted ||
            !activeSetViewModel.setProgress.isEmpty
        let hasExistingSession = isSameExercise && hasTrainingData

        if hasExistingSession {
            currentExercise = exercise
            isTrainingActive = true
        } else {
            activeSetViewModel.startSet(for: exercise, category: category)
            currentExercise = exercise
            isTrainingActive = true
        }
    }

    public func completeSet() {
        guard let exercise = activeSetViewModel.currentExercise else {
            return
        }

        guard activeSetViewModel.currentSet < exercise.sets && !activeSetViewModel.isLastSetCompleted else {
            return
        }

        activeSetViewModel.stopTimer()

        let isLastSet = (activeSetViewModel.currentSet + 1) >= exercise.sets

        activeSetViewModel.completeCurrentSet()

        if !isLastSet {
            activeSetViewModel.startNextSet()
        }
    }

    public func handleQuickDone() {
        guard let exercise = activeSetViewModel.currentExercise,
              let category = findCategory(exercise) else { return }

        activeSetViewModel.startQuickDone(for: exercise, category: category)
    }

    public func cancelTraining() {
        activeSetViewModel.cancelActiveSet()
        currentExercise = nil
        isTrainingActive = false
    }

    public func resetExercise() {
        activeSetViewModel.stopTimer()

        guard let exercise = activeSetViewModel.currentExercise,
              let category = findCategory(exercise) else { return }

        onExerciseReset(exercise, category)
        activeSetViewModel.resetProgress()

        currentExercise = nil
        isTrainingActive = false
    }

    public func editLess() {
        activeSetViewModel.stopTimer()

        let editIndex = activeSetViewModel.activeSetIndex

        guard editIndex >= 0 && editIndex < activeSetViewModel.setProgress.count else {
            return
        }

        activeSetViewModel.startEditingSet(index: editIndex, mode: .less)
    }

    public func editMore() {
        activeSetViewModel.stopTimer()

        let editIndex = activeSetViewModel.activeSetIndex

        guard editIndex >= 0 && editIndex < activeSetViewModel.setProgress.count else {
            return
        }

        activeSetViewModel.startEditingSet(index: editIndex, mode: .more)
    }

    public func finishExercise() {
        activeSetViewModel.stopTimer()

        guard let exercise = activeSetViewModel.currentExercise,
              let category = findCategory(exercise) else { return }

        saveAnalytics()

        if activeSetViewModel.isLastSetCompleted {
            var updatedExercise = exercise
            updatedExercise.isCompleted = true
            onExerciseUpdate(updatedExercise, category)
        }

        activeSetViewModel.finishExercise()
        activeSetViewModel.quickDoneModeActive = false

        currentExercise = nil
        isTrainingActive = false
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
            didJustEditSet: activeSetViewModel.didJustEditSet,
            showResetAllExercisesButton: false
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
            onCompleteAllQuickDone: {
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
                self?.onAddExercise()
            },
            onResetAllExercises: { [weak self] in
                self?.onResetAllExercises()
            }
        )
    }

    // MARK: - Analytics

    private func saveAnalytics() {
        guard let exercise = activeSetViewModel.currentExercise else {
            return
        }
        analyticsViewModel.saveAnalytics(
            exerciseId: exercise.id,
            setProgress: activeSetViewModel.setProgress
        )
    }

    // MARK: - Current Exercise Management

    public func setCurrentExercise(_ exercise: Exercise?) {
        currentExercise = exercise
        isTrainingActive = exercise != nil
        activeSetViewModel.currentExercise = exercise
    }

    // MARK: - Private Helpers

    private func setupActiveSetViewModelObserver() {
        observationTask?.cancel()
        var lastExerciseId: UUID? = activeSetViewModel.tracking.currentExercise?.id
        observationTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let newExercise = self.activeSetViewModel.tracking.currentExercise
                if newExercise?.id != lastExerciseId {
                    lastExerciseId = newExercise?.id
                    self.currentExercise = newExercise
                    self.isTrainingActive = newExercise != nil
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }
}
