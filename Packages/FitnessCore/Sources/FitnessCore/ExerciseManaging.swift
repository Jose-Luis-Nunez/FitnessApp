import Foundation
import Mockable

@Mockable
@MainActor
public protocol ExerciseManaging: AnyObject {
    func updateExercise(_ updatedExercise: Exercise, category: MuscleCategoryGroup)
    func getExercises(for category: MuscleCategoryGroup) -> [Exercise]
    func addExercise(_ exercise: Exercise, category: MuscleCategoryGroup, atTop: Bool)
    func completeExercise(_ exercise: Exercise, category: MuscleCategoryGroup, setProgress: [SetProgress])
    func resetExercise(_ exercise: Exercise, category: MuscleCategoryGroup)
    func resetAllExercises(for categories: [MuscleCategoryGroup])
    func getExerciseCount(for category: MuscleCategoryGroup) -> (total: Int, active: Int)
    func getAllExerciseCounts(for categories: [MuscleCategoryGroup]) -> [MuscleCategoryGroup: (total: Int, active: Int)]
    func hasInactiveExercises(for categories: [MuscleCategoryGroup]) -> Bool
}
