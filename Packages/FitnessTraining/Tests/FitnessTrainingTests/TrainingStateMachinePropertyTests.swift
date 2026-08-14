import Testing
import Foundation
import FitnessCore
@testable import FitnessTraining
import FitnessTestSupport

// MARK: - TrainingAction

/// All possible user actions on the training state machine.
/// Associated values are bounded to valid-ish ranges; `apply(to:)` guards
/// against out-of-bounds states the same way production code does.
enum TrainingAction: CustomStringConvertible, Sendable {
    case completeCurrentSet
    case startNextSet
    case cancelActiveSet
    case finishExercise
    case startQuickDone
    case editLess
    case editMore
    case updateReps(reps: Int, weight: Double)
    case resetProgress

    var description: String {
        switch self {
        case .completeCurrentSet: "completeCurrentSet"
        case .startNextSet: "startNextSet"
        case .cancelActiveSet: "cancelActiveSet"
        case .finishExercise: "finishExercise"
        case .startQuickDone: "startQuickDone"
        case .editLess: "editLess"
        case .editMore: "editMore"
        case .updateReps(let r, let w): "updateReps(\(r), \(w))"
        case .resetProgress: "resetProgress"
        }
    }

    /// Generates a random action using the provided RNG.
    static func random(using rng: inout some RandomNumberGenerator) -> TrainingAction {
        let kind = Int.random(in: 0...8, using: &rng)
        switch kind {
        case 0: return .completeCurrentSet
        case 1: return .startNextSet
        case 2: return .cancelActiveSet
        case 3: return .finishExercise
        case 4: return .startQuickDone
        case 5: return .editLess
        case 6: return .editMore
        case 7: return .updateReps(
            reps: Int.random(in: 1...20, using: &rng),
            weight: Double(Int.random(in: 5...100, using: &rng))
        )
        default: return .resetProgress
        }
    }
}

// MARK: - Action Execution

extension TrainingAction {
    /// Executes this action on the view model. Guards mirror production
    /// preconditions — invalid actions are silently skipped, just like in the
    /// real UI where buttons are hidden/disabled in certain states.
    @MainActor
    func apply(to vm: ActiveSetViewModel, exercise: Exercise, category: MuscleCategoryGroup) {
        switch self {
        case .completeCurrentSet:
            vm.completeCurrentSet()

        case .startNextSet:
            vm.startNextSet()

        case .cancelActiveSet:
            vm.cancelActiveSet()

        case .finishExercise:
            vm.finishExercise()

        case .startQuickDone:
            if let ex = vm.currentExercise {
                vm.startQuickDone(for: ex, category: category)
            }

        case .editLess:
            let idx = vm.activeSetIndex
            if idx >= 0 && idx < vm.setProgress.count {
                vm.startEditingSet(index: idx, mode: .less)
            }

        case .editMore:
            let idx = vm.activeSetIndex
            if idx >= 0 && idx < vm.setProgress.count {
                vm.startEditingSet(index: idx, mode: .more)
            }

        case .updateReps(let reps, let weight):
            if vm.currentExercise != nil {
                vm.updateCurrentReps(reps, weight)
            }

        case .resetProgress:
            vm.resetProgress()
        }
    }
}

// MARK: - Invariants

@MainActor
private func assertInvariants(
    _ vm: ActiveSetViewModel,
    exercise: Exercise,
    after action: TrainingAction,
    step: Int,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let ctx = "step \(step) after \(action)"

    // I1: currentSet is never negative
    #expect(
        vm.currentSet >= 0,
        "currentSet must be non-negative (\(ctx))",
        sourceLocation: sourceLocation
    )

    // I2: when an exercise is active, currentSet stays bounded
    if vm.currentExercise != nil {
        #expect(
            vm.currentSet <= exercise.trainingSteps.count,
            "currentSet (\(vm.currentSet)) must be <= trainingSteps.count (\(exercise.trainingSteps.count)) (\(ctx))",
            sourceLocation: sourceLocation
        )
    }

    // I3: setProgress length matches the derived execution plan (when populated)
    if !vm.setProgress.isEmpty {
        #expect(
            vm.setProgress.count == exercise.trainingSteps.count,
            "setProgress.count (\(vm.setProgress.count)) must match trainingSteps.count (\(exercise.trainingSteps.count)) (\(ctx))",
            sourceLocation: sourceLocation
        )
    }

    // I4: last-set completion implies no set is in-progress
    if vm.isLastSetCompleted {
        #expect(
            !vm.isSetInProgress,
            "isLastSetCompleted => !isSetInProgress (\(ctx))",
            sourceLocation: sourceLocation
        )
    }

    // I5: quickDoneAllCompleted implies isLastSetCompleted
    if vm.quickDoneAllCompleted && vm.currentExercise != nil {
        #expect(
            vm.isLastSetCompleted,
            "quickDoneAllCompleted => isLastSetCompleted (\(ctx))",
            sourceLocation: sourceLocation
        )
    }

    // I6: when exercise is cleared, core tracking state is also cleared
    if vm.currentExercise == nil && vm.setProgress.isEmpty {
        #expect(
            vm.currentSet == 0,
            "cleared exercise => currentSet == 0 (\(ctx))",
            sourceLocation: sourceLocation
        )
        #expect(
            !vm.isSetInProgress,
            "cleared exercise => !isSetInProgress (\(ctx))",
            sourceLocation: sourceLocation
        )
        #expect(
            !vm.isLastSetCompleted,
            "cleared exercise => !isLastSetCompleted (\(ctx))",
            sourceLocation: sourceLocation
        )
    }

    // I7: pendingEditIndex, when set, must point to a valid set
    if let editIndex = vm.pendingEditIndex {
        #expect(
            !vm.setProgress.isEmpty,
            "pendingEditIndex set (\(editIndex)) but setProgress is empty (\(ctx))",
            sourceLocation: sourceLocation
        )
        #expect(
            editIndex < vm.setProgress.count,
            "pendingEditIndex (\(editIndex)) must be < setProgress.count (\(vm.setProgress.count)) (\(ctx))",
            sourceLocation: sourceLocation
        )
    }
}

// MARK: - Seeded RNG for reproducibility

/// Lightweight deterministic RNG seeded from a UInt64. Allows reproducing
/// a failing sequence by logging the seed.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}

// MARK: - Property Tests

@Suite("Training State Machine — Property-Based", .tags(.fast))
@MainActor
struct TrainingStateMachinePropertyTests {

    private static let iterationCount = 200
    private static let sequenceLengthRange = 5...30

    private func generateAndRunSequence(
        exercise: Exercise,
        category: MuscleCategoryGroup,
        setup: (ActiveSetViewModel) -> Void,
        seed: UInt64,
        postCheck: ((ActiveSetViewModel) -> Void)? = nil,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        var rng = SeededRNG(seed: seed)
        let length = Int.random(in: Self.sequenceLengthRange, using: &rng)
        var actions: [TrainingAction] = []
        for _ in 0..<length {
            actions.append(.random(using: &rng))
        }

        let vm = ActiveSetViewModel()
        setup(vm)

        for (step, action) in actions.enumerated() {
            action.apply(to: vm, exercise: exercise, category: category)
            assertInvariants(
                vm, exercise: exercise, after: action, step: step,
                sourceLocation: sourceLocation
            )
        }

        postCheck?(vm)
    }

    @Test("Invariants hold for random action sequences after startSet", .timeLimit(.minutes(1)))
    func invariantsHoldFromStartSet() {
        let exercise = FitnessTestSupport.makeExercise(
            name: "Curl", weight: 20, reps: 10, sets: 3, category: .arms
        )

        for seed in UInt64(0)..<UInt64(Self.iterationCount) {
            generateAndRunSequence(
                exercise: exercise,
                category: .arms,
                setup: { $0.startSet(for: exercise, category: .arms) },
                seed: seed
            )
        }
    }

    @Test("Varying exercise sizes preserve invariants", .timeLimit(.minutes(1)))
    func varyingExerciseSizesPreserveInvariants() {
        let configurations: [(sets: Int, reps: Int, mode: ExerciseExecutionMode)] = [
            (1, 1, .standard),
            (1, 5, .bilateral),
            (2, 3, .standard),
            (3, 10, .bilateral),
            (5, 8, .standard),
            (10, 15, .bilateral)
        ]

        for (sets, reps, mode) in configurations {
            let exercise = FitnessTestSupport.makeExercise(
                name: "Test",
                weight: 20,
                reps: reps,
                sets: sets,
                category: .arms,
                executionMode: mode
            )
            for seed in UInt64(0)..<UInt64(50) {
                generateAndRunSequence(
                    exercise: exercise,
                    category: .arms,
                    setup: { $0.startSet(for: exercise, category: .arms) },
                    seed: seed &+ UInt64(sets) &* 1000
                )
            }
        }
    }
}
