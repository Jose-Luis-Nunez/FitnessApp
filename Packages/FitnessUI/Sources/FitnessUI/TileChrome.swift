import SwiftUI

/// The chrome every card tile wears: no fill, one hairline ring in the same grey
/// the circular controls use, clipped to the tile radius.
///
/// Shared rather than repeated so the set tiles and the coaching tiles cannot
/// drift apart — they had, with the coaching tile carrying a translucent white
/// fill and a wider white ring while the set tile had neither.
///
/// `strokeBorder`, not `stroke`: a centred stroke puts half its width outside the
/// shape, where the clip removes it, so the ring would render at half the token's
/// value. That is why the hairline width looks right here and looked doubled when
/// it was drawn with `stroke`.
struct TileChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: AppStyle.CornerRadius.tile, style: .continuous)
                    .strokeBorder(
                        AppStyle.Color.gray,
                        lineWidth: AppStyle.Layout.idlePlayRingWidth
                    )
            )
            .clipShape(
                RoundedRectangle(cornerRadius: AppStyle.CornerRadius.tile, style: .continuous)
            )
    }
}

extension View {
    /// See `TileChrome`.
    func tileChrome() -> some View {
        modifier(TileChrome())
    }
}
