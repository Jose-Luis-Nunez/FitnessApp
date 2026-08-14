import SwiftUI
import FitnessAnalytics
import FitnessResources
import FitnessUI

public struct StreakBannerView: View {
    @Environment(\.appColorTheme) private var appColorTheme
    @Environment(\.locale) private var locale
    public let streakData: StreakData

    public init(streakData: StreakData) {
        self.streakData = streakData
    }

    public var body: some View {
        HStack(spacing: 8) {
            streakTile(
                icon: "flame.fill",
                value: streakData.current.formatted(.number.locale(locale)),
                label: AppText.scheduleStreak
            )

            streakTile(
                icon: "trophy.fill",
                value: streakData.longest.formatted(.number.locale(locale)),
                label: AppText.scheduleBest
            )

            streakTile(
                icon: "metronome.fill",
                value: localizedRhythm,
                label: AppText.scheduleRhythm
            )
        }
    }

    private func streakTile(icon: String, value: String, label: LocalizedStringResource) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(AppStyle.Font.detailExercise)
                .foregroundColor(appColorTheme.accent.glow)

            Text(verbatim: value)
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

    private var localizedRhythm: String {
        AppText.resolve(streakData.rhythm.localizedResource, locale: locale)
    }
}
