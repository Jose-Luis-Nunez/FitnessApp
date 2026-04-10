import SwiftUI
import FitnessUI

public struct StreakBannerView: View {
    public let streakData: StreakData

    public init(streakData: StreakData) {
        self.streakData = streakData
    }

    public var body: some View {
        HStack(spacing: 8) {
            streakTile(
                icon: "flame.fill",
                value: "\(streakData.current)",
                label: "Streak"
            )

            streakTile(
                icon: "trophy.fill",
                value: "\(streakData.longest)",
                label: "Best"
            )

            streakTile(
                icon: "metronome.fill",
                value: streakData.rhythmLabel,
                label: "Rhythm"
            )
        }
    }

    private func streakTile(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(AppStyle.Font.detailExercise)
                .foregroundColor(AppStyle.Color.greenGlow)

            Text(value)
                .font(AppStyle.Font.streakValue)
                .foregroundColor(AppStyle.Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(AppStyle.Font.streakLabel)
                .foregroundColor(AppStyle.Color.white.opacity(0.5))
                .fixedSize()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card)
                .fill(Color.white.opacity(AppStyle.Opacity.subtleBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card)
                        .stroke(Color.white.opacity(AppStyle.Opacity.subtleStroke), lineWidth: 1)
                )
        )
    }
}
