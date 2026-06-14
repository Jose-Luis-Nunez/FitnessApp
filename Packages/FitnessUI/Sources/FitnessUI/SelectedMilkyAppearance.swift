import SwiftUI

/// The "milky" selection highlight used by the exercise multi-select mode.
/// A translucent `Color.white.opacity(0.15)` tint plus a thin white stroke —
/// the same selected-pill tint the bottom-menu-bar / filter-toggle use (see
/// `BottomMenuBarView` selection pill and `MuscleCategorySelectionView`
/// `filterToggleView`). No frosting material, so the card content stays clearly
/// visible through the tint.
public extension View {
    /// Overlays the milky selection tint when `isSelected`, clipped to the card
    /// corner radius. Non-interactive so the row's own tap stays intact.
    /// - Parameter horizontalInset: shrinks the tint on each side so it lines up
    ///   with a card whose visible background is inset from its layout bounds
    ///   (e.g. `CardShell` insets `CardBackground` by `AppStyle.Padding.card`).
    func selectedMilkyAppearance(
        isSelected: Bool,
        cornerRadius: CGFloat = AppStyle.CornerRadius.card,
        horizontalInset: CGFloat = 0
    ) -> some View {
        overlay {
            if isSelected {
                // Translucent milky tint — the card content stays clearly visible
                // through it; a thin white stroke marks the selection edge.
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppStyle.Color.white.opacity(AppStyle.Opacity.selectionTintFill))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(AppStyle.Color.white.opacity(AppStyle.Opacity.selectionTintStroke), lineWidth: 1)
                    )
                    .padding(.horizontal, horizontalInset)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
    }
}
