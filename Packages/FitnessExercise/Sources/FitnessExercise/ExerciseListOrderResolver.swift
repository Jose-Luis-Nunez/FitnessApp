import Foundation
@_spi(PersistenceUI) import FitnessStorage

enum ExerciseListOrderResolver {
    static func sorted(
        _ models: [ExerciseModel],
        learnedExerciseIds: [UUID]
    ) -> [ExerciseModel] {
        let learnedRanks = learnedExerciseIds.enumerated().reduce(into: [UUID: Int]()) {
            ranks, entry in
            if ranks[entry.element] == nil {
                ranks[entry.element] = entry.offset
            }
        }

        return models.sorted { lhs, rhs in
            switch (learnedRanks[lhs.id], learnedRanks[rhs.id]) {
            case let (left?, right?):
                return left < right
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                if lhs.category != rhs.category {
                    return lhs.category < rhs.category
                }
                return lhs.sortOrder < rhs.sortOrder
            }
        }
    }
}
