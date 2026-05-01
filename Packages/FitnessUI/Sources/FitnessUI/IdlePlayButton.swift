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
        ZStack {
            outerGlow
            ringedDisc
            playGlyph
        }
        // Frame matches the *outer glow* diameter so the layout container
        // reserves space for the entire halo. Without this the inner
        // `idlePlayButtonSize` would be reported as the component's bounds
        // and the glow would visually bleed into adjacent siblings (e.g.
        // overlap the Tip-Chip stacked above it).
        .frame(width: AppStyle.Layout.idlePlayButtonGlowSize,
               height: AppStyle.Layout.idlePlayButtonGlowSize)
    }

    // MARK: - Layers

    /// Soft mint halo painted behind the disc. The blur radius — not the
    /// disc size — creates the halo softness, so the disc itself stays
    /// nearly the same diameter as the button it sits behind.
    private var outerGlow: some View {
        Circle()
            .fill(AppStyle.Color.idlePlayRingGlow)
            .frame(width: AppStyle.Layout.idlePlayButtonGlowSize,
                   height: AppStyle.Layout.idlePlayButtonGlowSize)
            .blur(radius: AppStyle.Layout.idlePlayButtonGlowRadius)
    }

    /// Flat card-tinted disc with a hairline ring stroke. Filling with
    /// `idleCardBackground` (instead of a darker glass-dome gradient) makes
    /// the button look like a hole cut into the card surface — the only
    /// thing setting it apart is the ring + glyph + halo.
    private var ringedDisc: some View {
        Circle()
            .fill(AppStyle.Color.idleCardBackground)
            .overlay(
                Circle()
                    .strokeBorder(AppStyle.Color.idlePlayRingBase,
                                  lineWidth: AppStyle.Layout.idlePlayRingWidth)
            )
            .frame(width: AppStyle.Layout.idlePlayButtonSize,
                   height: AppStyle.Layout.idlePlayButtonSize)
    }

    private var playGlyph: some View {
        Image(systemName: "play.fill")
            .resizable()
            .scaledToFit()
            .frame(width: AppStyle.Layout.idlePlayIconSize,
                   height: AppStyle.Layout.idlePlayIconSize)
            .foregroundColor(AppStyle.Color.idleMetricValue)
            .offset(x: AppStyle.Layout.idlePlayIconOpticalOffset)
    }
}
