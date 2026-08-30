import Foundation
import Observation
import FitnessCore
import FitnessStorage
import FitnessAnalytics
import Factory

// MARK: - Active Training Target

/// The in-progress exercise a caller can jump back into, together with the
/// category group that owns its coordinator (needed to re-present the training
/// sheet).
public struct ActiveTrainingTarget: Equatable, Sendable, Identifiable {
    public var id: Exercise.ID { exercise.id }

    public let exercise: Exercise
    public let group: MuscleCategoryGroup

    public init(exercise: Exercise, group: MuscleCategoryGroup) {
        self.exercise = exercise
        self.group = group
    }
}

// MARK: - Protocol

@MainActor
public protocol TrainingCoordinatorCaching: AnyObject {
    func coordinator(for group: MuscleCategoryGroup) -> TrainingCoordinator
    func findCoordinator(for exercise: Exercise) -> (TrainingCoordinator, MuscleCategoryGroup)?

    /// Every exercise that is still in progress, across all category groups,
    /// most recently opened first. Empty when nothing is running.
    ///
    /// Deliberately without a protocol-extension default: an `[]` default would
    /// let a future conformer silently report "nothing is running", and the mini
    /// bar would just never appear, with nothing failing to compile.
    var activeTrainings: [ActiveTrainingTarget] { get }
}

// MARK: - Implementation

@Observable
@MainActor
public final class TrainingCoordinatorCache: TrainingCoordinatorCaching {
    /// Not observed: `coordinator(for:)` inserts lazily, and views call it from
    /// inside `body`, so tracking this dictionary would invalidate a view during
    /// its own update. Nothing is lost — every session change also mutates
    /// `focusRecency` and the coordinator's own observable state, which is what
    /// actually drives refreshes.
    @ObservationIgnored private var coordinators: [MuscleCategoryGroup: TrainingCoordinator] = [:]

    /// Exercise ids in the order they were last focused, oldest first. Only an
    /// ordering hint — whether an entry is still live is decided by asking its
    /// coordinator, so finishing or cancelling an exercise needs no bookkeeping
    /// here.
    private var focusRecency: [Exercise.ID] = []

    @ObservationIgnored private var exerciseManagementService: ExerciseManaging
    @ObservationIgnored private var exerciseOrderStorage: WorkoutExerciseOrderStoring
    @ObservationIgnored private let analyticsViewModel: AnalyticsViewModel

    public init(
        exerciseManagement: ExerciseManaging? = nil,
        exerciseOrderStorage: WorkoutExerciseOrderStoring? = nil,
        analyticsViewModel: AnalyticsViewModel? = nil
    ) {
        self.exerciseManagementService = exerciseManagement ?? Container.shared.exerciseManagement()
        self.exerciseOrderStorage = exerciseOrderStorage
            ?? Container.shared.workoutExerciseOrderStorage()
        self.analyticsViewModel = analyticsViewModel
            ?? Container.shared.analyticsViewModel()
    }

    public func coordinator(for group: MuscleCategoryGroup) -> TrainingCoordinator {
        if let existing = coordinators[group] {
            return existing
        }
        let coordinator = TrainingCoordinator(
            findCategory: { _ in group },
            onExerciseUpdate: { [weak self] exercise, category in
                self?.exerciseManagementService.updateExercise(exercise, category: category)
            },
            onExerciseReset: { [weak self] exercise, category in
                self?.exerciseManagementService.resetExercise(exercise, category: category)
            },
            onNewSessionStarted: { [weak self] workoutId, exerciseId in
                self?.exerciseOrderStorage.recordStart(
                    workoutId: workoutId,
                    exerciseId: exerciseId
                )
            },
            onSessionFocused: { [weak self] exerciseId in
                self?.recordFocus(exerciseId)
            },
            analyticsViewModel: analyticsViewModel
        )
        coordinators[group] = coordinator
        return coordinator
    }

    /// Deliberately computed on every read rather than cached in a stored
    /// property: the walk touches `focusRecency` and each coordinator's
    /// `activeExercises`, which is exactly what registers the observation that
    /// makes views refresh when a session starts or ends. A cached array would
    /// break that and go stale.
    public var activeTrainings: [ActiveTrainingTarget] {
        var targets: [ActiveTrainingTarget] = []

        for id in focusRecency.reversed() {
            // `first(where:)` rather than a loop with a break: an exercise belongs
            // to exactly one group, and stating that as a lookup makes it a fact
            // of the code instead of a loop that happens to stop early.
            guard let match = coordinators.first(where: { $0.value.isExerciseInProgress(id) }),
                  let exercise = match.value.activeExercises[id]
            else { continue }

            targets.append(ActiveTrainingTarget(exercise: exercise, group: match.key))
        }

        // Every insertion path runs through `setFocusedExerciseId`, so a running
        // exercise always has a recency entry. Reaching the body below therefore
        // means that invariant broke: it is surfaced rather than silently
        // repaired, because the recovered entries land in nondeterministic
        // dictionary order and would hide the regression behind a plausible list.
        // The list is still completed in release — an exercise the bar cannot
        // reach at all is worse than one in an unexpected position.
        let known = Set(targets.map(\.exercise.id))
        for (group, coordinator) in coordinators {
            for (id, exercise) in coordinator.activeExercises
            where !known.contains(id) && coordinator.isExerciseInProgress(id) {
                assertionFailure(
                    "Exercise \(id) is in progress in \(group) but missing from the focus recency"
                )
                targets.append(ActiveTrainingTarget(exercise: exercise, group: group))
            }
        }

        return targets
    }

    private func recordFocus(_ exerciseId: Exercise.ID) {
        focusRecency.removeAll { $0 == exerciseId }
        focusRecency.append(exerciseId)
    }

    public func findCoordinator(for exercise: Exercise) -> (TrainingCoordinator, MuscleCategoryGroup)? {
        for (group, coordinator) in coordinators {
            if coordinator.isExerciseInProgress(exercise.id) {
                return (coordinator, group)
            }
        }
        return nil
    }
}
