import SwiftUI

/// Shared visual for small circular card action icons (e.g. play, reset).
///
/// This is presentational-only and does not attach gestures. Callers wrap it in
/// `Button` and provide the action behavior.
///
/// `surface` selects between the two treatments below. It is one decision, not
/// two knobs: the halo only makes sense behind an opaque disc, because it is
/// larger than the disc and is meant to bleed out past its edge. Left visible
/// behind a transparent disc it fills the whole circle with a mint tint, which
/// is exactly what "transparent" is supposed to avoid.

/// How the circle behind the glyph is painted.
///
/// The blur radius belongs to `filled` rather than to the view: it only affects
/// the halo, so a transparent control could previously be handed a radius that
/// was silently ignored. The control's footprint is *not* part of this choice —
/// both treatments occupy the same space, which is what keeps a card's layout
/// unchanged when its button switches surface.
public enum CardActionCircleSurface: Equatable {
    /// Opaque card-coloured disc with a soft mint halo bleeding past its edge.
    /// Reads as a control punched out of the card surface.
    case filled(glowRadius: CGFloat = AppStyle.Layout.idlePlayButtonGlowRadius)
    /// No disc and no halo — only the hairline ring and the glyph. Use on
    /// screens carrying a backdrop that should show through the control.
    case clear
}

public struct CardActionCircleButtonVisual<Glyph: View>: View {
    @Environment(\.appColorTheme) private var appColorTheme
    let iconSize: CGFloat
    let discSize: CGFloat
    /// The control's outer footprint. Larger than `discSize`, because a filled
    /// surface's halo bleeds past the disc and needs the room.
    let frameSize: CGFloat
    let iconOffsetX: CGFloat
    let surface: CardActionCircleSurface
    let glyph: Glyph

    public init(
        iconSize: CGFloat,
        discSize: CGFloat,
        frameSize: CGFloat,
        iconOffsetX: CGFloat = 0,
        surface: CardActionCircleSurface,
        @ViewBuilder glyph: () -> Glyph
    ) {
        self.iconSize = iconSize
        self.discSize = discSize
        self.frameSize = frameSize
        self.iconOffsetX = iconOffsetX
        self.surface = surface
        self.glyph = glyph()
    }

    public var body: some View {
        ZStack {
            if case let .filled(glowRadius) = surface {
                Circle()
                    .fill(appColorTheme.accent.ringGlowBase.opacity(0.04))
                    .frame(width: frameSize, height: frameSize)
                    .blur(radius: glowRadius)

                Circle()
                    .fill(AppStyle.Color.idleCardBackground)
                    .frame(width: discSize, height: discSize)
            }

            Circle()
                .fill(Color.clear)
                .overlay(
                    Circle()
                        .strokeBorder(
                            AppStyle.Color.gray,
                            lineWidth: AppStyle.Layout.idlePlayRingWidth
                        )
                )
                .frame(width: discSize, height: discSize)

            glyph
                .frame(width: iconSize, height: iconSize)
                .foregroundColor(appColorTheme.accent.idleMetricValue)
                .offset(x: iconOffsetX)
        }
        .frame(width: frameSize, height: frameSize)
    }
}
