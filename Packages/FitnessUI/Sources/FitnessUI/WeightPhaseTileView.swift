import SwiftUI
import FitnessCore
import FitnessUI

public struct WeightPhaseTileView: View {
    public let phase: WeightPhase
    public let hasWeight: Bool

    public init(phase: WeightPhase, hasWeight: Bool) {
        self.phase = phase
        self.hasWeight = hasWeight
    }

    private var weightNumber: String {
        WeightFormatter.format(phase.weight)
    }

    private var durationText: String {
        phase.durationDays == 1 ? "Period: 1 Day" : "Period: \(phase.durationDays) Days"
    }

    private static let tileDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM"
        return f
    }()

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if hasWeight {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(weightNumber)
                        .font(AppStyle.Font.cardBoldTitle)
                        .foregroundColor(AppStyle.Color.greenGlow)
                    Text("KG")
                        .font(AppStyle.Font.cardSmallBold)
                        .foregroundColor(AppStyle.Color.greenGlow)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(phase.maxReps ?? 0)")
                        .font(AppStyle.Font.cardBoldTitle)
                        .foregroundColor(AppStyle.Color.greenGlow)
                    Text("Reps")
                        .font(AppStyle.Font.cardSmallBold)
                        .foregroundColor(AppStyle.Color.greenGlow)
                }
            }

            Text(durationText)
                .font(AppStyle.Font.cardSmallMedium)
                .foregroundColor(.white.opacity(0.6))

            HStack(spacing: 4) {
                Text("\(phase.sessionCount)")
                    .font(AppStyle.Font.cardSmallMedium)
                    .foregroundColor(.white)
                Text("to")
                    .font(AppStyle.Font.cardSmallMedium)
                    .foregroundColor(.white)
                Image(systemName: "arrow.up.right")
                    .font(AppStyle.Font.cardSmallBold)
                    .foregroundColor(AppStyle.Color.greenGlow)
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
                .foregroundColor(highlight ? AppStyle.Color.greenGlow : .white.opacity(0.5))
                .frame(width: 14, alignment: .center)
            Text(setsReps)
                .font(AppStyle.Font.detailCaption)
                .foregroundColor(highlight ? AppStyle.Color.greenGlow : .white.opacity(0.7))
            Text("(\(Self.tileDate.string(from: date)))")
                .font(AppStyle.Font.chartAxisSmall)
                .foregroundColor(.white.opacity(0.4))
        }
    }
}
