import FitnessUI
import SwiftUI

extension TotalAnalyticsView {

    var rhythmDetailView: some View {
        AnalyticsDetailSection(shouldShowIndicator: shouldShowRhythmScrollIndicator()) {
            AnalyticsDetailHeader(
                title: "Training Rhythm",
                subtitle: viewModel.getTrainingRhythmDetail()?.rhythmLabel,
                onBack: { showRhythmDetail = false }
            )
        } content: {
            rhythmDetailContent
        }
    }

    private var rhythmDetailContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let rhythmDetail = viewModel.getTrainingRhythmDetail() {

                VStack(alignment: .leading, spacing: 8) {
                    Text("Letzte 5 Trainingstage")
                        .font(AppStyle.Font.cardHeadline)
                        .foregroundColor(AppStyle.Color.greenGlow)

                    ForEach(rhythmDetail.trainingDates) { item in
                        HStack {
                            Text(DateFormatter.germanMedium.string(from: item.date))
                                .font(AppStyle.Font.detailExercise)
                                .foregroundColor(AppStyle.Color.greenGlow)

                            Spacer()

                            if item.id < rhythmDetail.gaps.count - 1 {
                                let gap = rhythmDetail.gaps[item.id]
                                let dayText = gap == 1 ? "Day" : "Days"
                                Text("\(gap) \(dayText)")
                                    .font(AppStyle.Font.detailCaption)
                                    .foregroundColor(AppStyle.Color.greenGlow.opacity(0.7))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(AppStyle.Color.greenGlow.opacity(0.15))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(AppStyle.Color.greenGlow.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                            }
                        }
                        .padding(.leading, 12)
                    }

                    if rhythmDetail.gaps.count > rhythmDetail.trainingDates.count - 1 {
                        HStack {
                            Text("Heute (\(DateFormatter.germanMedium.string(from: Date())))")
                                .font(AppStyle.Font.detailExercise)
                                .foregroundColor(AppStyle.Color.greenGlow)

                            Spacer()

                            let daysSinceLastTraining = rhythmDetail.gaps.last ?? 0
                            let dayText = daysSinceLastTraining == 1 ? "day" : "days"
                            Text("Last training \(daysSinceLastTraining) \(dayText) ago")
                                .font(AppStyle.Font.detailCaption)
                                .foregroundColor(daysSinceLastTraining > 7 ? AppStyle.Color.yellow : AppStyle.Color.greenGlow.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill((daysSinceLastTraining > 7 ? AppStyle.Color.yellow : AppStyle.Color.greenGlow).opacity(0.15))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke((daysSinceLastTraining > 7 ? AppStyle.Color.yellow : AppStyle.Color.greenGlow).opacity(0.3), lineWidth: 1)
                                        )
                                )
                        }
                        .padding(.leading, 12)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Berechnung")
                        .font(AppStyle.Font.cardHeadline)
                        .foregroundColor(AppStyle.Color.greenGlow)

                    Text(rhythmDetail.explanation)
                        .font(AppStyle.Font.detailExercise)
                        .foregroundColor(AppStyle.Color.greenGlow)
                        .padding(.leading, 12)
                        .lineSpacing(4)
                }

            } else {
                Text("Nicht genügend Trainingsdaten")
                    .font(AppStyle.Font.pickerAction)
                    .foregroundColor(AppStyle.Color.greenGlow.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 20)
            }
        }
        .padding(.top, 8)
    }

    func shouldShowRhythmScrollIndicator() -> Bool {
        guard let rhythmDetail = viewModel.getTrainingRhythmDetail() else { return false }
        return rhythmDetail.trainingDates.count > 3
    }
}
