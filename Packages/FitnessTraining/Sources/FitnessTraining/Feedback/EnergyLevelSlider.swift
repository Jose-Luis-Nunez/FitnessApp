import SwiftUI
import FitnessResources
import FitnessUI

/// Custom horizontal 1...5 energy slider with a thicker capsule track and a
/// light-green → dark-green fill gradient. SwiftUI's stock `Slider` cannot be
/// resized vertically, so the track, fill, and thumb are composed manually
/// inside a `ZStack` and a `DragGesture` snaps the value to whole integers.
///
/// Visual layout:
/// - `Low` / `High` labels above the track (no numeric "X / 5" indicator and
///   no tick-number row — the slider's position carries that information on
///   its own).
/// - 10pt-tall themed track overlaid by a fill capsule using the current
///   app accent gradient.
/// - 24pt white circular thumb centered on the current value.
struct EnergyLevelSlider: View {
    @Environment(\.appColorTheme) private var appColorTheme
    @Binding var selectedLevel: Int?

    private let minValue = 1
    private let maxValue = 5
    private let trackHeight: CGFloat = 10
    private let thumbSize: CGFloat = 24

    private var currentLevel: Int {
        selectedLevel ?? 3
    }

    /// Maps the 1...5 scale to a 0...100 % readout. The default thumb position
    /// (`currentLevel == 3`) maps to 50 % so the displayed value matches the
    /// visual fill exactly.
    private var percent: Int {
        let span = Double(maxValue - minValue)
        guard span > 0 else { return 0 }
        let progress = Double(currentLevel - minValue) / span
        return Int((progress * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(AppText.feedbackLow)
                    .font(AppStyle.Font.tileLabel)
                    .foregroundColor(AppStyle.Color.white.opacity(0.55))
                Spacer()
                Text(AppText.feedbackHigh)
                    .font(AppStyle.Font.tileLabel)
                    .foregroundColor(AppStyle.Color.white.opacity(0.55))
                if selectedLevel != nil {
                    Text(verbatim: "\(percent)%")
                        .font(AppStyle.Font.tileValue)
                        .foregroundColor(AppStyle.Color.white)
                        .padding(.leading, 8)
                }
            }

            GeometryReader { proxy in
                let width = proxy.size.width
                let progress = CGFloat(currentLevel - minValue) / CGFloat(maxValue - minValue)
                let thumbX = progress * width

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(appColorTheme.accent.dark)
                        .frame(height: trackHeight)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [appColorTheme.accent.light, appColorTheme.accent.primary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(thumbX, trackHeight), height: trackHeight)

                    Circle()
                        .fill(AppStyle.Color.white)
                        .frame(width: thumbSize, height: thumbSize)
                        .shadow(color: AppStyle.Color.black.opacity(0.35), radius: 2, y: 1)
                        .offset(x: thumbX - thumbSize / 2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            updateLevel(at: value.location.x, width: width)
                        }
                )
            }
            .frame(height: thumbSize)
            .accessibilityElement()
            .accessibilityIdentifier(TrainingIDs.energyLevelSlider)
            .accessibilityLabel(AppText.feedbackEnergyLevel)
            .accessibilityValue("\(percent)%")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    selectedLevel = min(maxValue, currentLevel + 1)
                case .decrement:
                    selectedLevel = max(minValue, currentLevel - 1)
                @unknown default:
                    break
                }
            }
        }
    }

    private func updateLevel(at x: CGFloat, width: CGFloat) {
        guard width > 0 else { return }
        let clamped = min(max(x, 0), width)
        let ratio = clamped / width
        let raw = Double(minValue) + ratio * Double(maxValue - minValue)
        selectedLevel = Int(raw.rounded())
    }
}
