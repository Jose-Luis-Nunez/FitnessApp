import SwiftUI

public struct ActiveSetEditPickerView: View {
    let title: String
    @Binding var selectedReps: String
    @Binding var selectedWeight: String
    let repsRange: ClosedRange<Int>
    let weightOptions: [String]
    let onSave: (Int, Double) -> Void
    let onCancel: () -> Void
    let saveDisabled: Bool

    let textColor: Color = AppStyle.Color.white
    @Environment(\.appColorTheme) private var appColorTheme

    private var pickerColor: Color { appColorTheme.accent.light }

    @State private var isShown: Bool = true
    @State private var showDecimal: Bool = false
    private var filteredWeightOptions: [String] {
        showDecimal ? weightOptions : weightOptions.filter { !$0.contains(",") && !$0.contains(".") }
    }

    public init(
        title: String,
        selectedReps: Binding<String>,
        selectedWeight: Binding<String>,
        repsRange: ClosedRange<Int>,
        weightOptions: [String],
        onSave: @escaping (Int, Double) -> Void,
        onCancel: @escaping () -> Void,
        saveDisabled: Bool
    ) {
        self.title = title
        _selectedReps = selectedReps
        _selectedWeight = selectedWeight
        self.repsRange = repsRange
        self.weightOptions = weightOptions
        self.onSave = onSave
        self.onCancel = onCancel
        self.saveDisabled = saveDisabled
    }

    public var body: some View {
        OverlaySheetContainer(
            isPresented: $isShown,
            onCancel: onCancel,
            actions: {
                ExercisePickerActionButtons(
                    saveDisabled: saveDisabled,
                    onCancel: { onCancel() },
                    onSave: {
                        if let reps = Int(selectedReps),
                           let weight = WeightFormatter.parse(selectedWeight) {
                            onSave(reps, weight)
                        }
                    }
                )
            },
            content: {
                VStack(spacing: 8) {
                    Text(title)
                        .font(AppStyle.Font.sheetTitle)
                        .foregroundColor(textColor)
                        .frame(maxWidth: .infinity)

                    HStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Text("Decimal")
                                .font(AppStyle.Font.tileLabel)
                                .foregroundColor(textColor.opacity(0.85))
                            Toggle("", isOn: $showDecimal)
                                .labelsHidden()
                                .toggleStyle(CapsuleToggleStyle(onColor: appColorTheme.accent.glow, offColor: AppStyle.Color.gray.opacity(AppStyle.Opacity.fadedOverlay)))
                        }
                    }
                }
                .padding(.bottom, AppStyle.Padding.sectionSpacing)

                VStack(spacing: 0) {
                    HStack {
                        Text("Weight")
                            .font(AppStyle.Font.sheetSectionLabel)
                            .foregroundColor(textColor)
                            .frame(maxWidth: .infinity)
                        Text("Reps")
                            .font(AppStyle.Font.sheetSectionLabel)
                            .foregroundColor(textColor)
                            .frame(maxWidth: .infinity)
                    }

                    HStack {
                        Picker("Weight", selection: $selectedWeight) {
                            ForEach(filteredWeightOptions, id: \.self) { value in
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

                        Picker("Reps", selection: $selectedReps) {
                            ForEach(repsRange.map(String.init), id: \.self) { value in
                                Text(value).tag(value).foregroundColor(pickerColor)
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
                    .frame(height: 120)
                }
            }
        )
        .onAppear {
            if selectedWeight.contains(",") || selectedWeight.contains(".") {
                showDecimal = true
            }
        }
    }
}
