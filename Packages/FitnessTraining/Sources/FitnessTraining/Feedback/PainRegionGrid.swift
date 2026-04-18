import SwiftUI
import FitnessCore
import FitnessUI

/// Grid-based **multi-select** picker for pain regions, pre-scoped to the
/// exercise's `BodyCategory`. Image-only tiles with `TrainingGlassEffectCompat`
/// background (Liquid Glass on iOS 26+, `ultraThinMaterial` fallback). Tapping
/// a tile toggles it in `selectedRegions` — any combination of regions in the
/// category can be active at once (e.g. lower back + obliques). Tapping an
/// already-selected tile removes it from the selection (ersetzt die frühere
/// "None"-Option des Wheel-Pickers).
struct PainRegionGrid: View {
    let category: BodyCategory
    let selectedRegions: Set<BodyRegion>
    let onToggle: (BodyRegion) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(BodyRegion.regions(in: category)) { r in
                PainRegionTile(
                    region: r,
                    isSelected: selectedRegions.contains(r),
                    onTap: { onToggle(r) }
                )
            }
        }
    }
}

struct PainRegionTile: View {
    let region: BodyRegion
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(AppStyle.Color.green.opacity(0.3))
                        .frame(width: 70, height: 70)
                        .blur(radius: 12)
                        .opacity(0.7)
                }

                Image(region.iconAssetName)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background {
                ZStack {
                    TrainingGlassEffectCompat.rectCard(cornerRadius: AppStyle.CornerRadius.tile)
                    if isSelected {
                        RoundedRectangle(cornerRadius: AppStyle.CornerRadius.tile, style: .continuous)
                            .fill(AppStyle.Color.green.opacity(0.1))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppStyle.CornerRadius.tile, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppStyle.CornerRadius.tile, style: .continuous)
                    .stroke(
                        isSelected ? AppStyle.Color.green : AppStyle.Color.gray,
                        lineWidth: 1
                    )
            )
            .accessibilityLabel(region.displayName)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
        }
        .buttonStyle(PlainButtonStyle())
    }
}
