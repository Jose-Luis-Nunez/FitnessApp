import SwiftUI

struct EditValueSheet: View {
    let title: String
    let placeholder: String
    @Binding var input: String
    let onSave: () -> Void
    let onCancel: () -> Void
    let keyboardType: UIKeyboardType
    let saveDisabled: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.headline)

            TextField(placeholder, text: $input)
                .keyboardType(keyboardType)
                .textFieldStyle(.roundedBorder)
                .padding()

            Button("Speichern", action: onSave)
                .buttonStyle(.borderedProminent)
                .disabled(saveDisabled)

            Button("Abbrechen", action: onCancel)
                .foregroundColor(.red)
        }
        .padding()
    }
}
