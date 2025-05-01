import Foundation

class ExerciseFormViewModel: ObservableObject {
    @Published var showForm: Bool = false
    @Published var name: String = ""
    @Published var weight: String = ""
    @Published var reps: String = ""
    @Published var sets: String = ""
    @Published var seat: String = ""

    var isFormValid: Bool {
        !name.isEmpty && !weight.isEmpty && !reps.isEmpty && !sets.isEmpty
    }

    func clearForm() {
        name = ""
        weight = ""
        reps = ""
        sets = ""
        seat = ""
        showForm = false
    }

    func toggleForm() {
        showForm.toggle()
    }

    func createExercise() -> Exercise? {
        guard isFormValid,
              let weightInt = Int(weight),
              let repsInt = Int(reps),
              let setsInt = Int(sets) else { return nil }
        
        return Exercise(
            name: name,
            weight: weightInt,
            reps: repsInt,
            sets: setsInt,
            seatSetting: seat.isEmpty ? nil : seat
        )
    }
}
