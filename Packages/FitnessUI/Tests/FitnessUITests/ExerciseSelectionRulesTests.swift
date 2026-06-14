import Testing
@testable import FitnessUI

@Suite("ExerciseSelectionRules — deactivate/activate selectability")
struct ExerciseSelectionRulesTests {

    @Test("None mode selects nothing")
    func noneSelectsNothing() {
        for active in [true, false] {
            for completed in [true, false] {
                for inProgress in [true, false] {
                    #expect(ExerciseSelectionRules.isSelectable(
                        mode: .none, isActive: active, isCompleted: completed, isInProgress: inProgress
                    ) == false)
                }
            }
        }
    }

    @Test("Deactivate selects only idle (active, not completed, not in progress)")
    func deactivateSelectsOnlyIdle() {
        #expect(ExerciseSelectionRules.isSelectable(mode: .deactivate, isActive: true, isCompleted: false, isInProgress: false))
        // not idle → not selectable
        #expect(!ExerciseSelectionRules.isSelectable(mode: .deactivate, isActive: true, isCompleted: true, isInProgress: false))
        #expect(!ExerciseSelectionRules.isSelectable(mode: .deactivate, isActive: true, isCompleted: false, isInProgress: true))
        // already deactivated → not selectable for deactivation
        #expect(!ExerciseSelectionRules.isSelectable(mode: .deactivate, isActive: false, isCompleted: false, isInProgress: false))
    }

    @Test("Deactivate truth table: only active && !completed && !inProgress")
    func deactivateTruthTable() {
        for active in [true, false] {
            for completed in [true, false] {
                for inProgress in [true, false] {
                    let expected = active && !completed && !inProgress
                    #expect(ExerciseSelectionRules.isSelectable(
                        mode: .deactivate, isActive: active, isCompleted: completed, isInProgress: inProgress
                    ) == expected)
                }
            }
        }
    }

    @Test("Activate truth table: selectable iff deactivated, regardless of other state")
    func activateTruthTable() {
        for active in [true, false] {
            for completed in [true, false] {
                for inProgress in [true, false] {
                    #expect(ExerciseSelectionRules.isSelectable(
                        mode: .activate, isActive: active, isCompleted: completed, isInProgress: inProgress
                    ) == !active)
                }
            }
        }
    }

    @Test("Activate selects only deactivated exercises")
    func activateSelectsOnlyDeactivated() {
        #expect(ExerciseSelectionRules.isSelectable(mode: .activate, isActive: false, isCompleted: false, isInProgress: false))
        // completion/in-progress are irrelevant for a deactivated (hidden) exercise
        #expect(ExerciseSelectionRules.isSelectable(mode: .activate, isActive: false, isCompleted: true, isInProgress: true))
        // active exercises are not activatable
        #expect(!ExerciseSelectionRules.isSelectable(mode: .activate, isActive: true, isCompleted: false, isInProgress: false))
    }
}
