import SwiftUI

/// Decorative play button used in the idle exercise card.
///
/// Composition (back-to-front):
/// - no disc and no halo, so whatever the screen puts behind the card shows
///   through the button unchanged,
/// - a neutral-grey hairline ring,
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
            frameSize: AppStyle.Layout.idlePlayButtonGlowSize,
            iconOffsetX: AppStyle.Layout.idlePlayIconOpticalOffset,
            surface: .clear
        ) {
            Image(systemName: "play.fill")
                .resizable()
                .scaledToFit()
        }
    }
}
