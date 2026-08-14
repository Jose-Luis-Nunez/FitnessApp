import SwiftUI
import FitnessCore
import FitnessResources
import FitnessUI

struct SymptomChipsView: View {
    let selected: Set<Symptom>
    let onToggle: (Symptom) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Symptom.allCases) { symptom in
                SymptomTile(
                    symptom: symptom,
                    isSelected: selected.contains(symptom),
                    action: { onToggle(symptom) }
                )
                .accessibilityIdentifier(TrainingIDs.symptomChip(symptom.rawValue))
            }
        }
        .padding(.horizontal, 18)
    }
}

private struct SymptomTile: View {
    @Environment(\.appColorTheme) private var appColorTheme
    let symptom: Symptom
    let isSelected: Bool
    let action: () -> Void

    private var iconName: String {
        switch symptom {
        case .pain:           return "bolt.fill"
        case .dizziness:      return "tornado"
        case .nausea:         return "face.dashed"
        case .muscleWeakness: return "dumbbell.fill"
        }
    }

    private var accentColor: Color { symptom.iconColor(in: appColorTheme) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: iconName)
                    .font(AppStyle.Font.iconSymbol)
                    .foregroundColor(isSelected
                                     ? accentColor
                                     : accentColor.opacity(0.7))
                    .frame(width: 32, height: 32)

                Text(symptom.localizedName)
                    .font(AppStyle.Font.cardSmallBold)
                    .foregroundColor(isSelected
                                     ? accentColor
                                     : AppStyle.Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(symptom.localizedDescription)
                    .font(AppStyle.Font.detailCaption)
                    .foregroundColor(AppStyle.Color.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(minHeight: 14, alignment: .top)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background {
                ZStack {
                    TrainingControlSurfaceStyle.surface(
                        in: RoundedRectangle(
                            cornerRadius: AppStyle.CornerRadius.tile,
                            style: .continuous
                        )
                    )

                    if isSelected {
                        RoundedRectangle(
                            cornerRadius: AppStyle.CornerRadius.tile,
                            style: .continuous
                        )
                        .fill(accentColor.opacity(0.10))
                        .overlay {
                            RoundedRectangle(
                                cornerRadius: AppStyle.CornerRadius.tile,
                                style: .continuous
                            )
                            .stroke(accentColor, lineWidth: 1.5)
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppStyle.CornerRadius.tile, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
