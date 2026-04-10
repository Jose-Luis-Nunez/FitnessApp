import SwiftUI
import FitnessUI

// MARK: - Shared Wheel Picker Row
// Sheet chrome (`ExercisePickerActionButtons`, `exercisePickerSheet`) lives in `FitnessUI`.

public struct ExerciseWheelPickerRow: View {
    @Binding public var sets: Int
    @Binding public var reps: Int
    @Binding public var weight: String
    public let setsRange: ClosedRange<Int>
    public let repsRange: ClosedRange<Int>
    public let weightOptions: [String]
    public var showWeight: Bool = true

    public init(
        sets: Binding<Int>,
        reps: Binding<Int>,
        weight: Binding<String>,
        setsRange: ClosedRange<Int>,
        repsRange: ClosedRange<Int>,
        weightOptions: [String],
        showWeight: Bool = true
    ) {
        _sets = sets
        _reps = reps
        _weight = weight
        self.setsRange = setsRange
        self.repsRange = repsRange
        self.weightOptions = weightOptions
        self.showWeight = showWeight
    }

    private let textColor: Color = AppStyle.Color.white
    private let pickerColor: Color = AppStyle.Color.greenLight

    public var body: some View {
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
#if os(iOS)
                .pickerStyle(.wheel)
#else
                .pickerStyle(.menu)
#endif
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
#if os(iOS)
                .pickerStyle(.wheel)
#else
                .pickerStyle(.menu)
#endif
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
#if os(iOS)
                    .pickerStyle(.wheel)
#else
                    .pickerStyle(.menu)
#endif
                    .frame(maxWidth: .infinity)
                    .clipped()
                }
            }
        }
        .frame(height: 150)
    }
}

// MARK: - Shared Input Fields

public struct ExercisePickerInputFieldStyle: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
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

public struct ExercisePickerInputField: View {
    public var prompt: String?
    @Binding public var text: String

    public init(prompt: String? = nil, text: Binding<String>) {
        self.prompt = prompt
        _text = text
    }

    public var body: some View {
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
