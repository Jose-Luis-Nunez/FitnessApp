import Foundation
import Observation
import FitnessCore

@Observable
@MainActor
public final class ExerciseFormViewModel {
    public var showForm: Bool = false
    public var editMode: ExerciseEditMode = .full
    public var name: String = ""
    public var weight: Double = 0.0
    public var reps: Int = 1
    public var sets: Int = 1
    public var seat: String = ""
    public var noSeats: Bool = false
    public var editingExercise: Exercise?
    public var selectedIconName: String = ""
    public var selectedCategory: MuscleCategoryGroup = .arms
    public var executionMode: ExerciseExecutionMode = .standard

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
        executionMode = .standard
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
            var updatedExercise = existingExercise
            updatedExercise.name = name
            updatedExercise.weight = weight
            updatedExercise.reps = reps
            updatedExercise.sets = sets
            updatedExercise.seatSetting = seat.isEmpty ? nil : seat
            updatedExercise.noSeats = noSeats
            updatedExercise.iconName = icon
            updatedExercise.category = selectedCategory
            updatedExercise.executionMode = executionMode
            return updatedExercise
        } else {
            return Exercise(
                name: name,
                weight: weight,
                reps: reps,
                sets: sets,
                seatSetting: seat.isEmpty ? nil : seat,
                noSeats: noSeats,
                iconName: icon,
                category: selectedCategory,
                executionMode: executionMode
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
            executionMode = exercise.executionMode
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
