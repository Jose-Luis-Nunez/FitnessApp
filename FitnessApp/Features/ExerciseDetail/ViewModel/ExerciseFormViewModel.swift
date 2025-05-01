import Foundation

class ExerciseFormViewModel: ObservableObject {
    @Published var showForm: Bool = false
    @Published var name: String = ""
    @Published var weight: Int = 0
    @Published var reps: Int = 1
    @Published var sets: Int = 1
    @Published var seat: String = ""
    @Published var editingExercise: Exercise?

    var isFormValid: Bool {
        !name.isEmpty && reps > 0 && sets > 0
    }

    func clearForm() {
        name = ""
        weight = 0
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
        
        if let existingExercise = editingExercise {
            // Bearbeiten einer bestehenden Übung
            return Exercise(
                id: existingExercise.id,
                name: name,
                weight: weight,
                reps: reps,
                sets: sets,
                seatSetting: seat.isEmpty ? nil : seat,
                isCompleted: existingExercise.isCompleted
            )
        } else {
            // Neue Übung erstellen
            return Exercise(
                name: name,
                weight: weight,
                reps: reps,
                sets: sets,
                seatSetting: seat.isEmpty ? nil : seat
            )
        }
    }
    
    func loadExercise(_ exercise: Exercise?) {
        if let exercise = exercise {
            name = exercise.name
            weight = exercise.weight
            reps = exercise.reps
            sets = exercise.sets
            seat = exercise.seatSetting ?? ""
            editingExercise = exercise
        } else {
            clearForm()
            editingExercise = nil
        }
    }
}
