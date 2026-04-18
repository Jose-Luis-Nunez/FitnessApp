import SwiftUI
import FitnessUI

/// Horizontal 1...5 slider used to capture a subjective energy level.
/// Snaps to whole integers. Uses dark-green tint, consistent with the
/// primary training palette. Binding allows nil to represent "not set".
struct EnergyLevelSlider: View {
    @Binding var selectedLevel: Int?

    private let range: ClosedRange<Double> = 1...5

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { Double(selectedLevel ?? 3) },
            set: { newValue in
                selectedLevel = Int(newValue.rounded())
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Low")
                    .font(AppStyle.Font.tileLabel)
                    .foregroundColor(AppStyle.Color.white.opacity(0.55))
                Spacer()
                if let level = selectedLevel {
                    Text("\(level) / 5")
                        .font(AppStyle.Font.tileLabel)
                        .foregroundColor(AppStyle.Color.greenLight)
                }
                Spacer()
                Text("High")
                    .font(AppStyle.Font.tileLabel)
                    .foregroundColor(AppStyle.Color.white.opacity(0.55))
            }

            Slider(
                value: sliderBinding,
                in: range,
                step: 1
            )
            .tint(AppStyle.Color.greenDark)
            .accessibilityIdentifier(TrainingIDs.energyLevelSlider)

            HStack {
                ForEach(1...5, id: \.self) { tick in
                    Text("\(tick)")
                        .font(AppStyle.Font.cardSmallLabel)
                        .foregroundColor(AppStyle.Color.white.opacity(0.45))
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
