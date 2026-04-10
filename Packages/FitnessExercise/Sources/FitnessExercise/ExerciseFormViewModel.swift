import Foundation
import FitnessCore

public class ExerciseFormViewModel: ObservableObject {
    @Published public var showForm: Bool = false
    @Published public var editMode: ExerciseEditMode = .full
    @Published public var name: String = ""
    @Published public var weight: Double = 0.0
    @Published public var reps: Int = 1
    @Published public var sets: Int = 1
    @Published public var seat: String = ""
    @Published public var noSeats: Bool = false
    @Published public var editingExercise: Exercise?
    @Published public var selectedIconName: String = ""
    @Published public var selectedCategory: MuscleCategoryGroup = .arms

    public init() {}

    public var isFormValid: Bool {
        !name.isEmpty && reps > 0 && sets > 0
    }

    public func clearForm() {
        name = ""
        weight = 0.0
        reps = 1
        sets = 1
        seat = ""
        noSeats = false
        editingExercise = nil
        editMode = .full
        showForm = false
    }

    public func toggleForm() {
        showForm.toggle()
        if !showForm {
            clearForm()
        }
    }

    public func createOrUpdateExercise() -> Exercise? {
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
                noSeats: noSeats,
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
                noSeats: noSeats,
                iconName: icon,
                category: selectedCategory
            )
        }
    }

    public func loadExercise(_ exercise: Exercise?, category: MuscleCategoryGroup) {
        selectedCategory = category
        if let exercise = exercise {
            name = exercise.name
            weight = exercise.weight
            reps = exercise.reps
            sets = exercise.sets
            seat = exercise.seatSetting ?? ""
            noSeats = exercise.noSeats
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
