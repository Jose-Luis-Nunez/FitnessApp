import SwiftUI

// MARK: - Shared Sheet Modifier

struct ExercisePickerSheetModifier: ViewModifier {
    let isContentVisible: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 28)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AppStyle.Color.sheetBackground)
            )
            .frame(maxWidth: .infinity)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .opacity(isContentVisible ? 1 : 0)
            .allowsHitTesting(isContentVisible)
    }
}

extension View {
    func exercisePickerSheet(isContentVisible: Bool) -> some View {
        modifier(ExercisePickerSheetModifier(isContentVisible: isContentVisible))
    }
}

// MARK: - Shared Action Buttons

struct ExercisePickerActionButtons: View {
    let saveDisabled: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack {
            Spacer()

            Text("Cancel")
                .foregroundColor(.white)
                .font(.system(size: 14))
                .padding(5)
                .frame(width: 120)
                .cornerRadius(AppStyle.CornerRadius.editPickerViewButton)
                .onTapGesture { onCancel() }
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer()

            Button("Save") { onSave() }
                .foregroundColor(.white)
                .font(.system(size: 14))
                .padding(5)
                .frame(width: 140, height: 40)
                .background(saveDisabled ? AppStyle.Color.green.opacity(0.15) : AppStyle.Color.green)
                .cornerRadius(AppStyle.CornerRadius.editPickerViewButton)
                .disabled(saveDisabled)
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer()
        }
        .padding(.horizontal, 5)
    }
}

// MARK: - Shared Wheel Picker Row

struct ExerciseWheelPickerRow: View {
    @Binding var sets: Int
    @Binding var reps: Int
    @Binding var weight: String
    let setsRange: ClosedRange<Int>
    let repsRange: ClosedRange<Int>
    let weightOptions: [String]
    var showWeight: Bool = true

    private let textColor: Color = AppStyle.Color.white
    private let pickerColor: Color = AppStyle.Color.greenLight

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack {
                Text("Set")
                    .font(.headline)
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity)
                Picker("Sets", selection: $sets) {
                    ForEach(setsRange, id: \.self) { value in
                        Text("\(value)").tag(value).foregroundColor(pickerColor)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()
            }

            VStack {
                Text("Reps")
                    .font(.headline)
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity)
                Picker("Reps", selection: $reps) {
                    ForEach(repsRange, id: \.self) { value in
                        Text("\(value)").tag(value).foregroundColor(pickerColor)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()
            }

            if showWeight {
                VStack {
                    Text("Weight")
                        .font(.headline)
                        .foregroundColor(textColor)
                        .frame(maxWidth: .infinity)
                    Picker("Weight", selection: $weight) {
                        ForEach(weightOptions, id: \.self) { value in
                            Text("\(value) kg").tag(value).foregroundColor(pickerColor)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()
                }
            }
        }
        .frame(height: 150)
    }
}

// MARK: - Shared Input Fields

struct ExercisePickerInputFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .foregroundColor(AppStyle.Color.white)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppStyle.Color.sheetInputBackground)
            )
    }
}

struct ExercisePickerInputField: View {
    var prompt: String?
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            if let prompt = prompt {
                ZStack(alignment: .leading) {
                    if text.isEmpty {
                        Text(prompt)
                            .foregroundColor(Color.white.opacity(0.55))
                    }
                    TextField("", text: $text)
                        .accentColor(AppStyle.Color.white)
                        .foregroundColor(AppStyle.Color.white)
                        .textFieldStyle(PlainTextFieldStyle())
                }
            } else {
                TextField("", text: $text)
                    .accentColor(AppStyle.Color.white)
                    .foregroundColor(AppStyle.Color.white)
                    .textFieldStyle(PlainTextFieldStyle())
            }

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.white.opacity(0.5))
                }
            }
        }
        .compositingGroup()
        .modifier(ExercisePickerInputFieldStyle())
    }
}
