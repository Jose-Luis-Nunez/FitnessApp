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

}
