import SwiftUI

/// Shared visual for small circular card action icons (e.g. play, reset).
///
/// This is presentational-only and does not attach gestures. Callers wrap it in
/// `Button` and provide the action behavior.
public struct CardActionCircleButtonVisual<Glyph: View>: View {
    @Environment(\.appColorTheme) private var appColorTheme
    let iconSize: CGFloat
    let discSize: CGFloat
    let glowSize: CGFloat
    let glowRadius: CGFloat
    let iconOffsetX: CGFloat
    let glyph: Glyph

    public init(
        iconSize: CGFloat,
        discSize: CGFloat,
        glowSize: CGFloat,
        glowRadius: CGFloat = AppStyle.Layout.idlePlayButtonGlowRadius,
        iconOffsetX: CGFloat = 0,
        @ViewBuilder glyph: () -> Glyph
    ) {
        self.iconSize = iconSize
        self.discSize = discSize
        self.glowSize = glowSize
        self.glowRadius = glowRadius
        self.iconOffsetX = iconOffsetX
        self.glyph = glyph()
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(appColorTheme.accent.ringGlowBase.opacity(0.04))
                .frame(width: glowSize, height: glowSize)
                .blur(radius: glowRadius)

            Circle()
                .fill(AppStyle.Color.idleCardBackground)
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
        .frame(width: glowSize, height: glowSize)
    }
}
