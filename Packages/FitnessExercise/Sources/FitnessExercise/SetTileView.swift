import SwiftUI
import FitnessCore
import FitnessUI

public struct SetTileView: View {
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
                .foregroundColor(AppStyle.Color.greenGlow)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

                Text("\(reps) reps")
                    .font(AppStyle.Font.cardTinyLabel)
                    .foregroundColor(.white.opacity(0.7))
            } else {
                Text("\(reps)")
                    .font(AppStyle.Font.cardValueBold)
                    .foregroundColor(AppStyle.Color.greenGlow)

                Text("reps")
                    .font(AppStyle.Font.cardTinyLabel)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .overlay(
            RoundedRectangle(cornerRadius: AppStyle.CornerRadius.defaultButton)
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.CornerRadius.defaultButton))
    }
}
