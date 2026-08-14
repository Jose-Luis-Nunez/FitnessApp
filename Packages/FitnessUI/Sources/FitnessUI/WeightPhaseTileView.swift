import SwiftUI
import FitnessCore
import FitnessResources

public struct WeightPhaseTileView: View {
    @Environment(\.appColorTheme) private var appColorTheme
    @Environment(\.locale) private var locale
    public let phase: WeightPhase
    public let hasWeight: Bool

    public init(phase: WeightPhase, hasWeight: Bool) {
        self.phase = phase
        self.hasWeight = hasWeight
    }

    private var weightNumber: String {
        WeightFormatter.format(phase.weight, locale: locale)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if hasWeight {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(verbatim: weightNumber)
                        .font(AppStyle.Font.cardBoldTitle)
                        .foregroundColor(appColorTheme.accent.glow)
                    Text(verbatim: "KG")
                        .font(AppStyle.Font.cardSmallBold)
                        .foregroundColor(appColorTheme.accent.glow)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(verbatim: "\(phase.maxReps ?? 0)")
                        .font(AppStyle.Font.cardBoldTitle)
                        .foregroundColor(appColorTheme.accent.glow)
                    Text(AppText.exerciseReps)
                        .font(AppStyle.Font.cardSmallBold)
                        .foregroundColor(appColorTheme.accent.glow)
                }
            }

            Text(AppText.analyticsPeriodDays(count: phase.durationDays))
                .font(AppStyle.Font.cardSmallMedium)
                .foregroundColor(.white.opacity(0.6))

            HStack(spacing: 4) {
                Text(verbatim: "\(phase.sessionCount)")
                    .font(AppStyle.Font.cardSmallMedium)
                    .foregroundColor(.white)
                Text(AppText.analyticsTo)
                    .font(AppStyle.Font.cardSmallMedium)
                    .foregroundColor(.white)
                Image(systemName: "arrow.up.right")
                    .font(AppStyle.Font.cardSmallBold)
                    .foregroundColor(appColorTheme.accent.glow)
            }

            Spacer(minLength: 2)

            resultRow(icon: "mappin.and.ellipse", setsReps: phase.startSetsReps, date: phase.startDate, highlight: false)
            resultRow(icon: "flag.fill", setsReps: phase.endSetsReps, date: phase.endDate, highlight: phase.hasImproved)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(AppStyle.Opacity.subtleBackground))
        .overlay(
            RoundedRectangle(cornerRadius: AppStyle.CornerRadius.tile)
                .stroke(Color.white.opacity(AppStyle.Opacity.subtleStroke), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.CornerRadius.tile))
    }

    private func resultRow(icon: String, setsReps: String, date: Date, highlight: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(AppStyle.Font.chartAxisSmall)
                .foregroundColor(highlight ? appColorTheme.accent.glow : .white.opacity(0.5))
                .frame(width: 14, alignment: .center)
            Text(verbatim: setsReps)
                .font(AppStyle.Font.detailCaption)
                .foregroundColor(highlight ? appColorTheme.accent.glow : .white.opacity(0.7))
            Text(verbatim: "(\(date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).locale(locale))))")
                .font(AppStyle.Font.chartAxisSmall)
                .foregroundColor(.white.opacity(0.4))
        }
    }
}
