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
        HStack(alignment: .top, spacing: 10) {
            column("Set") {
                Picker("Sets", selection: $sets) {
                    ForEach(setsRange, id: \.self) { value in
                        Text("\(value)").tag(value).foregroundColor(pickerColor)
                    }
                }
            }

            column("Reps") {
                Picker("Reps", selection: $reps) {
                    ForEach(repsRange, id: \.self) { value in
                        Text("\(value)").tag(value).foregroundColor(pickerColor)
                    }
                }
            }

            if showWeight {
                column("Weight") {
                    Picker("Weight", selection: $weight) {
                        ForEach(weightOptions, id: \.self) { value in
                            Text("\(value) kg").tag(value).foregroundColor(pickerColor)
                        }
                    }
                }
            }
        }
        .frame(height: 184)
    }

    /// Card look: header pinned to the top, the wheel constrained to a fixed
    /// 3-row height and centered in the remaining card space.
    @ViewBuilder
    private func column<Picker: View>(_ title: String, @ViewBuilder picker: () -> Picker) -> some View {
        VStack(spacing: 0) {
            header(title).padding(.top, 12)
            Spacer(minLength: 0)
            styledPicker(picker())
                .frame(height: cardWheelHeight)
                .clipped()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(AppStyle.Color.idleCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                        .stroke(AppStyle.Color.white.opacity(AppStyle.Opacity.subtleStroke), lineWidth: 1)
                )
        )
    }

    /// Wheel height tuned to show exactly three rows (selected + one above/below)
    /// inside the taller card.
    private let cardWheelHeight: CGFloat = 116
    /// Corner radius of the per-column card.
    private let cardCornerRadius: CGFloat = 16

    private func header(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func styledPicker<Picker: View>(_ picker: Picker) -> some View {
        picker
#if os(iOS)
            .pickerStyle(.wheel)
#else
            .pickerStyle(.menu)
#endif
            .frame(maxWidth: .infinity)
    }
}
