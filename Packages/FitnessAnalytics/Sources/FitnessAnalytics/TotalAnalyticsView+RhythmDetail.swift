import FitnessResources
import FitnessUI
import SwiftUI

extension TotalAnalyticsView {

    var rhythmDetailView: some View {
        AnalyticsDetailSection(shouldShowIndicator: shouldShowRhythmScrollIndicator()) {
            AnalyticsDetailHeader(
                title: AppText.analyticsTrainingRhythm,
                subtitle: rhythmDetailData.map { AppText.resolve($0.rhythm.localizedResource, locale: locale) },
                onBack: { showRhythmDetail = false }
            )
        } content: {
            rhythmDetailContent
        }
    }

    private var rhythmDetailContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let rhythmDetail = rhythmDetailData {

                VStack(alignment: .leading, spacing: 8) {
                    Text(AppText.trainingLastFiveDays)
                        .font(AppStyle.Font.cardHeadline)
                        .foregroundColor(appColorTheme.accent.glow)

                    ForEach(rhythmDetail.trainingDates) { item in
                        HStack {
                            Text(verbatim: item.date.formatted(.dateTime.day().month(.wide).year().locale(locale)))
                                .font(AppStyle.Font.detailExercise)
                                .foregroundColor(appColorTheme.accent.glow)

                            Spacer()

                            if item.id < rhythmDetail.gaps.count - 1 {
                                let gap = rhythmDetail.gaps[item.id]
                                Text(AppText.analyticsDayCount(count: gap))
                                    .font(AppStyle.Font.detailCaption)
                                    .foregroundColor(appColorTheme.accent.glow.opacity(0.7))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(appColorTheme.accent.glow.opacity(0.15))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(appColorTheme.accent.glow.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                            }
                        }
                        .padding(.leading, 12)
                    }

                    if rhythmDetail.gaps.count > rhythmDetail.trainingDates.count - 1 {
                        HStack {
                            Text(AppText.analyticsToday(date: Date().formatted(.dateTime.day().month(.wide).year().locale(locale))))
                                .font(AppStyle.Font.detailExercise)
                                .foregroundColor(appColorTheme.accent.glow)

                            Spacer()

                            let daysSinceLastTraining = rhythmDetail.daysSinceLastTraining
                            Text(AppText.trainingDaysAgo(count: daysSinceLastTraining))
                                .font(AppStyle.Font.detailCaption)
                                .foregroundColor(daysSinceLastTraining > 7 ? AppStyle.Color.yellow : appColorTheme.accent.glow.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill((daysSinceLastTraining > 7 ? AppStyle.Color.yellow : appColorTheme.accent.glow).opacity(0.15))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke((daysSinceLastTraining > 7 ? AppStyle.Color.yellow : appColorTheme.accent.glow).opacity(0.3), lineWidth: 1)
                                        )
                                )
                        }
                        .padding(.leading, 12)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(AppText.commonCalculation)
                        .font(AppStyle.Font.cardHeadline)
                        .foregroundColor(appColorTheme.accent.glow)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppText.analyticsHistoricalGapsLine(gaps: rhythmDetail.gaps.dropLast().map(String.init).joined(separator: ", ")))
                        Text(AppText.analyticsAverageLine(average: rhythmDetail.averageGap.formatted(.number.precision(.fractionLength(1)).locale(locale))))
                        Text(AppText.analyticsSinceLastTrainingLine(days: rhythmDetail.daysSinceLastTraining))
                        Text(AppText.analyticsResultLine(result: AppText.resolve(rhythmDetail.rhythm.localizedResource, locale: locale)))
                    }
                        .font(AppStyle.Font.detailExercise)
                        .foregroundColor(appColorTheme.accent.glow)
                        .padding(.leading, 12)
                        .lineSpacing(4)
                }

            } else {
                Text(AppText.analyticsNotEnoughTrainingData)
                    .font(AppStyle.Font.pickerAction)
                    .foregroundColor(appColorTheme.accent.glow.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 20)
            }
        }
        .padding(.top, 8)
    }

    func shouldShowRhythmScrollIndicator() -> Bool {
        guard let rhythmDetail = rhythmDetailData else { return false }
        return rhythmDetail.trainingDates.count > 3
    }
}
