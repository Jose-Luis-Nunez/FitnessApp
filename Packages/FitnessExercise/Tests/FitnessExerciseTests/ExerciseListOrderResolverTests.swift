import Foundation
import Testing
@testable import FitnessExercise
@_spi(PersistenceUI) import FitnessStorage

@Suite("ExerciseListOrderResolver", .tags(.fast))
struct ExerciseListOrderResolverTests {
    @Test("Learned exercises lead across categories and unknown exercises use fallback order")
    func learnedOrderWithFallback() {
        let armsSecond = makeModel(category: "arms", sortOrder: 1)
        let chestFirst = makeModel(category: "chest", sortOrder: 0)
        let armsFirst = makeModel(category: "arms", sortOrder: 0)
        let legsFirst = makeModel(category: "legs", sortOrder: 0)

        let result = ExerciseListOrderResolver.sorted(
            [legsFirst, armsSecond, chestFirst, armsFirst],
            learnedExerciseIds: [chestFirst.id, armsSecond.id]
        )

        #expect(result.map(\.id) == [
            chestFirst.id,
            armsSecond.id,
            armsFirst.id,
            legsFirst.id
        ])
    }

    @Test("Empty learned order preserves category and sortOrder behavior")
    func emptyLearnedOrderUsesExistingFallback() {
        let chest = makeModel(category: "chest", sortOrder: 0)
        let armsSecond = makeModel(category: "arms", sortOrder: 1)
        let armsFirst = makeModel(category: "arms", sortOrder: 0)

        let result = ExerciseListOrderResolver.sorted(
            [chest, armsSecond, armsFirst],
            learnedExerciseIds: []
        )

        #expect(result.map(\.id) == [armsFirst.id, armsSecond.id, chest.id])
    }

    private func makeModel(category: String, sortOrder: Int) -> ExerciseModel {
        ExerciseModel(
            id: UUID(),
            name: "Exercise",
            weight: 10,
            reps: 10,
            sets: 3,
            iconName: "defaultArmsIcon",
            category: category,
            sortOrder: sortOrder
        )
    }
}
