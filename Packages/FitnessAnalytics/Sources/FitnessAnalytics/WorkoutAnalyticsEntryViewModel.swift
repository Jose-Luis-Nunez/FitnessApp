import Factory
import FitnessCore
import FitnessStorage
import Foundation
import Observation

struct WorkoutAnalyticsExerciseDraft: Identifiable {
    let exercise: Exercise
    var isSelected: Bool
    var entry: AnalyticsEntry

    var id: UUID { exercise.id }

    var setCount: Int {
        switch exercise.executionMode {
        case .standard:
            entry.setProgress.count
        case .bilateral:
            Set(
                entry.setProgress.enumerated().map { index, progress in
                    progress.logicalSetIndex ?? index / ExerciseSide.allCases.count
                }
            ).count
        }
    }
}

enum WorkoutAnalyticsSaveState: Equatable {
    case editing
    case saving
    case saved
}

@Observable
@MainActor
final class WorkoutAnalyticsEntryViewModel {
    let workout: Workout
    var selectedDate: Date
    private(set) var drafts: [WorkoutAnalyticsExerciseDraft] = []
    private(set) var saveState: WorkoutAnalyticsSaveState = .editing
    private(set) var saveFailed = false

    @ObservationIgnored private let exerciseStorage: ExerciseStoring
    @ObservationIgnored private let saveUseCase: SaveWorkoutAnalyticsUseCase
    @ObservationIgnored private let analyticsViewModel: AnalyticsViewModel

    init(
        workout: Workout,
        selectedDate: Date = Date(),
        exerciseStorage: ExerciseStoring? = nil,
        saveUseCase: SaveWorkoutAnalyticsUseCase? = nil,
        analyticsViewModel: AnalyticsViewModel? = nil
    ) {
        self.workout = workout
        self.selectedDate = selectedDate
        self.exerciseStorage = exerciseStorage
            ?? Container.shared.exerciseStorage()
        self.saveUseCase = saveUseCase
            ?? Container.shared.saveWorkoutAnalyticsUseCase()
        self.analyticsViewModel = analyticsViewModel
            ?? Container.shared.analyticsViewModel()
        loadDrafts()
    }

    var selectedCount: Int {
        drafts.filter(\.isSelected).count
    }

    var canSave: Bool {
        saveState == .editing
            && selectedCount > 0
            && drafts.filter(\.isSelected).allSatisfy(isValid)
    }

    func toggleSelection(for exerciseId: UUID) {
        guard saveState == .editing,
              let index = drafts.firstIndex(where: { $0.id == exerciseId })
        else { return }
        drafts[index].isSelected.toggle()
    }

    func draft(for exerciseId: UUID) -> WorkoutAnalyticsExerciseDraft? {
        drafts.first { $0.id == exerciseId }
    }

    func updateDraft(exerciseId: UUID, with entry: AnalyticsEntry) {
        guard saveState == .editing,
              let index = drafts.firstIndex(where: { $0.id == exerciseId })
        else { return }
        drafts[index].entry = AnalyticsEntry(
            id: entry.id,
            exerciseId: exerciseId,
            date: selectedDate,
            setProgress: entry.setProgress
        )
    }

    /// Performs at most one save for this ViewModel's lifetime.
    @discardableResult
    func save() -> Bool {
        guard canSave else { return false }
        saveState = .saving
        saveFailed = false

        let entries = drafts
            .filter(\.isSelected)
            .map {
                AnalyticsEntry(
                    exerciseId: $0.exercise.id,
                    date: selectedDate,
                    setProgress: $0.entry.setProgress
                )
            }

        guard saveUseCase.execute(entries: entries) == entries.count else {
            saveState = .editing
            saveFailed = true
            return false
        }
        analyticsViewModel.publishPersistedEntries(entries)
        saveState = .saved
        return true
    }

    private func loadDrafts() {
        drafts = MuscleCategoryGroup.allCases.flatMap { category in
            exerciseStorage
                .loadForWorkout(workoutId: workout.id, category: category)
                .filter(\.isActive)
                .map { exercise in
                    WorkoutAnalyticsExerciseDraft(
                        exercise: exercise,
                        isSelected: true,
                        entry: makeDefaultEntry(for: exercise)
                    )
                }
        }
    }

    private func makeDefaultEntry(for exercise: Exercise) -> AnalyticsEntry {
        let progress = exercise.trainingSteps.map { step in
            SetProgress(
                status: .completedDone,
                currentReps: exercise.reps,
                weight: exercise.weight,
                side: step.side,
                logicalSetIndex: step.logicalSetIndex
            )
        }
        return AnalyticsEntry(
            exerciseId: exercise.id,
            date: selectedDate,
            setProgress: progress
        )
    }

    private func isValid(_ draft: WorkoutAnalyticsExerciseDraft) -> Bool {
        !draft.entry.setProgress.isEmpty
            && draft.entry.setProgress.allSatisfy { progress in
                progress.currentReps > 0
                    && (!draft.exercise.hasWeight || progress.weight > 0)
            }
    }
}
