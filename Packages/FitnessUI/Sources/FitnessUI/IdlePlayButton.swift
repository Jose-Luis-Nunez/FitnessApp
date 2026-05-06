import SwiftUI

/// Decorative play button used in the idle exercise card.
///
/// Composition (back-to-front):
/// - a soft mint outer halo,
/// - a flat disc filled with `idleCardBackground` so the button reads as a
///   "punched out" extension of the card surface,
/// - a hairline metallic ring stroke (`idlePlayRingBase`),
/// - the SF Symbol play glyph, optically nudged for visual centering.
///
/// All visual constants are sourced from `AppStyle` so design-system
/// consistency is preserved. The component itself owns no state and is
/// purely presentational; the caller wraps it in a `Button` (or any other
/// gesture surface) and provides the action.
public struct IdlePlayButton: View {

    public init() {}

    public var body: some View {
        CardActionCircleButtonVisual(
            iconSize: AppStyle.Layout.idlePlayIconSize,
            discSize: AppStyle.Layout.idlePlayButtonSize,
            glowSize: AppStyle.Layout.idlePlayButtonGlowSize,
            iconOffsetX: AppStyle.Layout.idlePlayIconOpticalOffset
        ) {
            Image(systemName: "play.fill")
                .resizable()
                .scaledToFit()
        }
    }
}
