import Foundation

class ExerciseFormViewModel: ObservableObject {
    @Published var showForm: Bool = false
    @Published var name: String = ""
    @Published var weight: Double = 0.0
    @Published var reps: Int = 1
    @Published var sets: Int = 1
    @Published var seat: String = ""
    @Published var editingExercise: Exercise?
    @Published var selectedIconName: String = ""
    @Published var selectedCategory: MuscleCategoryGroup = .arms
    
    var isFormValid: Bool {
        !name.isEmpty && reps > 0 && sets > 0
    }
    
    func clearForm() {
        name = ""
        weight = 0.0
        reps = 1
        sets = 1
        seat = ""
        editingExercise = nil
        showForm = false
    }
    
    func toggleForm() {
        showForm.toggle()
        if !showForm {
            clearForm()
        }
    }
    
    func createOrUpdateExercise() -> Exercise? {
        guard isFormValid else { return nil }
        
        let icon = selectedIconName.isEmpty
        ? selectedCategory.defaultIconName
        : selectedIconName
        
        if let existingExercise = editingExercise {
            return Exercise(
                id: existingExercise.id,
                name: name,
                weight: weight,
                reps: reps,
                sets: sets,
                seatSetting: seat.isEmpty ? nil : seat,
                isCompleted: existingExercise.isCompleted,
                iconName: icon,
                category: selectedCategory
            )
        } else {
            return Exercise(
                name: name,
                weight: weight,
                reps: reps,
                sets: sets,
                seatSetting: seat.isEmpty ? nil : seat,
                iconName: icon,
                category: selectedCategory
                
            )
        }
    }
    
    func loadExercise(_ exercise: Exercise?, category: MuscleCategoryGroup) {
        selectedCategory = category
        if let exercise = exercise {
            name = exercise.name
            weight = exercise.weight
            reps = exercise.reps
            sets = exercise.sets
            seat = exercise.seatSetting ?? ""
            let validIcons = category.availableIcons
            if validIcons.contains(exercise.iconName) {
                selectedIconName = exercise.iconName
            } else {
                selectedIconName = category.defaultIconName
            }
            editingExercise = exercise
        } else {
            clearForm()
            editingExercise = nil
            selectedCategory = category
            selectedIconName = ""
        }
    }
}
