import SwiftUI
import FitnessCore
import FitnessResources
import FitnessUI

struct SymptomChipsView: View {
    let selected: Set<Symptom>
    let onToggle: (Symptom) -> Void

    /// The grid spans the sheet's full content width — the enclosing stack
    /// already applies the margin, so adding one here would push the tiles out
    /// of line with every other element. The shortened symptom descriptions are
    /// instead given room by the wider column gutter, which narrows the tiles
    /// without moving their outer edges.
    private static let columnGutter: CGFloat = 20
    private static let rowSpacing: CGFloat = 10

    private let columns = [
        GridItem(.flexible(), spacing: Self.columnGutter),
        GridItem(.flexible(), spacing: Self.columnGutter)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Self.rowSpacing) {
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

    /// The symptom tiles share the active-set timer card's outline treatment —
    /// `TrainingControlSurfaceStyle` already gives them its colour and line
    /// width, so they take its corner radius too instead of the generic tile
    /// radius, otherwise the two surfaces read as different components.
    private static let cornerRadius = AppStyle.CornerRadius.timerCard

    /// The tiles are the sheet's primary control and claim the vertical room
    /// freed by tightening the header. A floor rather than a fixed height, so a
    /// longer localized label can still push a tile taller instead of clipping.
    private static let minimumHeight: CGFloat = 88

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
                    // Same grey as the timer card's Cancel label — both are
                    // supporting copy under a primary control.
                    .foregroundColor(AppStyle.Color.idleMetricLabel)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(minHeight: 14, alignment: .top)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .frame(minHeight: Self.minimumHeight)
            .background {
                ZStack {
                    TrainingControlSurfaceStyle.surface(
                        in: RoundedRectangle(
                            cornerRadius: Self.cornerRadius,
                            style: .continuous
                        )
                    )

                    if isSelected {
                        RoundedRectangle(
                            cornerRadius: Self.cornerRadius,
                            style: .continuous
                        )
                        .fill(accentColor.opacity(0.10))
                        .overlay {
                            RoundedRectangle(
                                cornerRadius: Self.cornerRadius,
                                style: .continuous
                            )
                            // Same line width as the shared outline it replaces,
                            // so selecting a tile changes its colour, not its
                            // weight.
                            .stroke(
                                accentColor,
                                lineWidth: AppStyle.Layout.darkSurfaceOutlineWidth
                            )
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
