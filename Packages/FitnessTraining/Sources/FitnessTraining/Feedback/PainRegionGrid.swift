import SwiftUI
import FitnessCore
import FitnessUI

/// Grid-based **multi-select** picker for pain regions, pre-scoped to the
/// exercise's `BodyCategory`. Image-only tiles use the same transparent dark
/// surface and outline as the training timer, so the sheet gradient remains
/// visible instead of gaining a separate grey glass layer. Tapping a tile
/// toggles it in `selectedRegions` — any combination of regions in the category
/// can be active at once (e.g. lower back + obliques). Tapping an already-
/// selected tile removes it from the selection.
struct PainRegionGrid: View {
    let category: BodyCategory
    let selectedRegions: Set<BodyRegion>
    let onToggle: (BodyRegion) -> Void
    let imageProvider: (BodyRegion) -> Image

    init(
        category: BodyCategory,
        selectedRegions: Set<BodyRegion>,
        onToggle: @escaping (BodyRegion) -> Void,
        imageProvider: @escaping (BodyRegion) -> Image = {
            Image($0.iconAssetName)
        }
    ) {
        self.category = category
        self.selectedRegions = selectedRegions
        self.onToggle = onToggle
        self.imageProvider = imageProvider
    }

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
                    image: imageProvider(r),
                    onTap: { onToggle(r) }
                )
            }
        }
    }
}

struct PainRegionTile: View {
    @Environment(\.appColorTheme) private var appColorTheme
    let region: BodyRegion
    let isSelected: Bool
    let image: Image
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(appColorTheme.accent.primary.opacity(0.3))
                        .frame(width: 70, height: 70)
                        .blur(radius: 12)
                        .opacity(0.7)
                }

                image
                    .resizable()
                    .scaledToFit()
                    .padding(6)
                    .saturation(1.07)
                    .brightness(0.03)
                    .colorMultiply(appColorTheme.accent.light)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
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
                            .fill(appColorTheme.accent.primary.opacity(0.1))
                            .overlay {
                                RoundedRectangle(
                                    cornerRadius: AppStyle.CornerRadius.tile,
                                    style: .continuous
                                )
                                .stroke(appColorTheme.accent.primary, lineWidth: 1.5)
                            }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppStyle.CornerRadius.tile, style: .continuous))
            .accessibilityLabel(region.displayName)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
        }
        .buttonStyle(PlainButtonStyle())
    }
}
