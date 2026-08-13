import SwiftUI
import FitnessCore

public struct SetTileView: View {
    @Environment(\.appColorTheme) private var appColorTheme
    public let setNumber: Int
    public let weight: Double
    public let reps: Int
    public let hasWeight: Bool

    public init(setNumber: Int, weight: Double, reps: Int, hasWeight: Bool) {
        self.setNumber = setNumber
        self.weight = weight
        self.reps = reps
        self.hasWeight = hasWeight
    }

    private var weightText: String {
        WeightFormatter.format(weight)
    }

    public var body: some View {
        VStack(spacing: 2) {
            Text("SET \(setNumber)")
                .font(AppStyle.Font.cardSmallLabel)
                .foregroundColor(.white.opacity(0.7))

            if hasWeight {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(weightText)
                        .font(AppStyle.Font.cardValueBold)
                    Text("kg")
                        .font(AppStyle.Font.chartAxisSmall)
                }
                .foregroundColor(appColorTheme.accent.light)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

                Text("\(reps) reps")
                    .font(AppStyle.Font.cardTinyLabel)
                    .foregroundColor(.white.opacity(0.7))
            } else {
                Text("\(reps)")
                    .font(AppStyle.Font.cardValueBold)
                    .foregroundColor(appColorTheme.accent.light)

                Text("reps")
                    .font(AppStyle.Font.cardTinyLabel)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        // Inner fill / stroke mirror the "New Exercise" wheel picker columns
        // (see `ExerciseWheelPickerRow`); the smaller `.tile` radius keeps the
        // compact set tile from reading too round at this size.
        .background(
            RoundedRectangle(cornerRadius: AppStyle.CornerRadius.tile, style: .continuous)
                .fill(AppStyle.Color.idleCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppStyle.CornerRadius.tile, style: .continuous)
                .stroke(AppStyle.Color.white.opacity(AppStyle.Opacity.subtleStroke), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.CornerRadius.tile, style: .continuous))
    }
}
