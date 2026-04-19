import SwiftUI
import FitnessCore
import FitnessUI

struct SymptomChipsView: View {
    let selected: Set<Symptom>
    let onToggle: (Symptom) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Symptom.allCases) { symptom in
                SymptomTile(
                    symptom: symptom,
                    isSelected: selected.contains(symptom),
                    action: { onToggle(symptom) }
                )
                .accessibilityIdentifier(TrainingIDs.symptomChip(symptom.rawValue))
            }
        }
    }
}

private struct SymptomTile: View {
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

    private var accentColor: Color { symptom.iconColor }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(accentColor.opacity(0.3))
                            .frame(width: 60, height: 60)
                            .blur(radius: AppStyle.Blur.iconGlow)
                            .opacity(0.7)
                    }
                    Circle()
                        .fill(isSelected
                              ? accentColor.opacity(0.15)
                              : AppStyle.Color.chipsBackground)
                        .frame(width: 48, height: 48)
                    Image(systemName: iconName)
                        .font(AppStyle.Font.iconSymbol)
                        .foregroundColor(isSelected
                                         ? accentColor
                                         : accentColor.opacity(0.7))
                }
                .padding(.top, 4)

                Text(symptom.displayName.uppercased())
                    .font(AppStyle.Font.cardSmallBold)
                    .foregroundColor(isSelected
                                     ? accentColor
                                     : AppStyle.Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(symptom.description)
                    .font(AppStyle.Font.detailCaption)
                    .foregroundColor(AppStyle.Color.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(minHeight: 16, alignment: .top)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .background {
                ZStack {
                    TrainingGlassEffectCompat.rectCard(cornerRadius: AppStyle.CornerRadius.tile)
                    if isSelected {
                        RoundedRectangle(cornerRadius: AppStyle.CornerRadius.tile, style: .continuous)
                            .fill(accentColor.opacity(0.10))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppStyle.CornerRadius.tile, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppStyle.CornerRadius.tile, style: .continuous)
                    .stroke(isSelected
                            ? accentColor
                            : AppStyle.Color.white.opacity(0.10),
                            lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
