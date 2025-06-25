import Foundation

final class MuscleCategorySelectionViewModel: ObservableObject {
    @Published var groups: [MuscleCategoryGroup] = MuscleCategoryGroup.allCases
    private let storageService = ExerciseStorageService()
    
    @Published private var exerciseCounts: [MuscleCategoryGroup: (total: Int, active: Int)] = [:]
    
    init() {
        updateExerciseCounts()
    }
    
    func updateExerciseCounts() {
        for group in MuscleCategoryGroup.allCases {
            let exercises = storageService.load(for: group)
            exerciseCounts[group] = (total: exercises.count, active: exercises.filter { !$0.isCompleted }.count)
        }
    }
    
    func getExerciseCount(for group: MuscleCategoryGroup) -> (total: Int, active: Int)? {
        exerciseCounts[group]
    }
}
