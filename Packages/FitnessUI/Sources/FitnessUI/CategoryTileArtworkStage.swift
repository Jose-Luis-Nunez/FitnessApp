import SwiftUI

/// The shared, centered artwork stage used by category tiles.
/// Callers provide the image so asset lookup remains in the feature's bundle.
public struct CategoryTileArtworkStage<Artwork: View>: View {
    private let alignment: Alignment
    private let artwork: Artwork

    public init(
        alignment: Alignment,
        @ViewBuilder artwork: () -> Artwork
    ) {
        self.alignment = alignment
        self.artwork = artwork()
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(AppStyle.Color.greenBlack)
                .frame(
                    width: ExerciseCardLayout.CategoryTile.iconGlowSize,
                    height: ExerciseCardLayout.CategoryTile.iconGlowSize
                )
                .blur(radius: ExerciseCardLayout.CategoryTile.iconGlowBlurRadius)
                .opacity(AppStyle.Opacity.categoryTileIconGlow)

            artwork
                .frame(
                    width: ExerciseCardLayout.CategoryTile.iconArtworkSize,
                    height: ExerciseCardLayout.CategoryTile.iconArtworkSize,
                    alignment: alignment
                )
                .clipped()
        }
        .frame(
            width: ExerciseCardLayout.CategoryTile.iconSize,
            height: ExerciseCardLayout.CategoryTile.iconSize
        )
    }
}
