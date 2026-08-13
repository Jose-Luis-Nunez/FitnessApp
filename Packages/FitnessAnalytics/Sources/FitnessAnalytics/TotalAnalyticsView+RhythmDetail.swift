import FitnessUI
import SwiftUI

extension TotalAnalyticsView {

    var rhythmDetailView: some View {
        AnalyticsDetailSection(shouldShowIndicator: shouldShowRhythmScrollIndicator()) {
            AnalyticsDetailHeader(
                title: "Training Rhythm",
                subtitle: rhythmDetailData?.rhythmLabel,
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
                    Text("Last 5 training days")
                        .font(AppStyle.Font.cardHeadline)
                        .foregroundColor(appColorTheme.accent.glow)

                    ForEach(rhythmDetail.trainingDates) { item in
                        HStack {
                            Text(DateFormatter.germanMedium.string(from: item.date))
                                .font(AppStyle.Font.detailExercise)
                                .foregroundColor(appColorTheme.accent.glow)

                            Spacer()

                            if item.id < rhythmDetail.gaps.count - 1 {
                                let gap = rhythmDetail.gaps[item.id]
                                let dayText = gap == 1 ? "Day" : "Days"
                                Text("\(gap) \(dayText)")
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
                            Text("Today (\(DateFormatter.germanMedium.string(from: Date())))")
                                .font(AppStyle.Font.detailExercise)
                                .foregroundColor(appColorTheme.accent.glow)

                            Spacer()

                            let daysSinceLastTraining = rhythmDetail.gaps.last ?? 0
                            let dayText = daysSinceLastTraining == 1 ? "day" : "days"
                            Text("Last training \(daysSinceLastTraining) \(dayText) ago")
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
                    Text("Calculation")
                        .font(AppStyle.Font.cardHeadline)
                        .foregroundColor(appColorTheme.accent.glow)

                    Text(rhythmDetail.explanation)
                        .font(AppStyle.Font.detailExercise)
                        .foregroundColor(appColorTheme.accent.glow)
                        .padding(.leading, 12)
                        .lineSpacing(4)
                }

            } else {
                Text("Not enough training data")
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
