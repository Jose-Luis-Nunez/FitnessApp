import SwiftUI

struct EditPickerView: View {
    let title: String
    @Binding var selectedReps: String
    @Binding var selectedWeight: String
    let repsRange: ClosedRange<Int>
    let weightRange: ClosedRange<Int>
    let onSave: (Int, Int) -> Void
    let onCancel: () -> Void
    let saveDisabled: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                WheelPickerView(
                    title: "Wiederholungen auswählen",
                    selectedValue: $selectedReps,
                    range: repsRange,
                    unit: ""
                )
                
                WheelPickerView(
                    title: "Gewicht auswählen",
                    selectedValue: $selectedWeight,
                    range: weightRange,
                    unit: "kg"
                )
                
                Spacer()
            }
            .padding()
            .navigationTitle(title)
            .navigationBarItems(
                leading: Button("Abbrechen") {
                    onCancel()
                },
                trailing: Button("Speichern") {
                    if let reps = Int(selectedReps), let weight = Int(selectedWeight) {
                        onSave(reps, weight)
                    }
                }
                    .disabled(saveDisabled)
            )
        }
    }
}
