import SwiftUI

/// The backdrop shared by every bottom sheet in the training flow: the ambient
/// screen washes clipped to the sheet's own corners, plus the card border.
///
/// Extracted because the training sheet, the feedback sheet, and the Less/More
/// picker each used to carry their own copy of this treatment — which is why
/// they kept drifting apart. Anything presented as one of those sibling sheets
/// should use this rather than describe its own surface.
public struct AmbientSheetSurface: View {
    public init() {}

    /// Top corners only: these sheets are anchored to the bottom edge, so the
    /// bottom corners never become visible.
    public static var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: AppStyle.CornerRadius.sheet,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: AppStyle.CornerRadius.sheet,
            style: .continuous
        )
    }

    public var body: some View {
        AmbientScreenBackground()
            .clipShape(Self.shape)
            .overlay {
                Self.shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                AppStyle.Color.idleCardBorderLight,
                                AppStyle.Color.idleCardBorderDark,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: AppStyle.Layout.idleCardBorderWidth
                    )
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea(edges: .bottom)
    }
}
