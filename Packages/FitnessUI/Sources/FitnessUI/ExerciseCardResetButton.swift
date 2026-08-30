import SwiftUI
import FitnessResources

/// Circular reset button shown on completed exercise cards.
///
/// Hoisted into `FitnessUI` as part of T7-0 so `InactiveCardModelView` in
/// `FitnessPersistenceUI` can reuse it without re-introducing a dependency
/// cycle. Layout constants (size, iconSize) live alongside as
/// `ExerciseCardLayout.ResetButton` (canonical source).
public struct ExerciseCardResetButton: View {
    public let onTap: () -> Void
    private let image: Image

    /// The glyph comes from the caller; there is deliberately no convenience
    /// initializer that loads `Image("repeat")` itself. Every exercise card
    /// already resolves its artwork through an injected provider, and the
    /// internal lookup resolved to nothing outside the app bundle — which is
    /// how the button came to render as an empty circle in a snapshot. A second
    /// initializer would keep that trap available.
    public init(image: Image, onTap: @escaping () -> Void) {
        self.onTap = onTap
        self.image = image
    }

    public var body: some View {
        Button(action: onTap) {
            CardActionCircleButtonVisual(
                iconSize: ExerciseCardLayout.ResetButton.iconSize,
                discSize: ExerciseCardLayout.ResetButton.size,
                frameSize: ExerciseCardLayout.ResetButton.size,
                surface: .clear
            ) {
                image
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
            }
            // The visual stays a 40pt circle; only the touch area grows to the
            // documented minimum. Without this the control was 4pt short in both
            // axes — the surrounding column widened it, but nothing raised it.
            .frame(
                minWidth: AppStyle.Layout.minimumTapTargetSize,
                minHeight: AppStyle.Layout.minimumTapTargetSize
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Without this VoiceOver falls back to the asset name and announces
        // "repeat".
        .accessibilityLabel(Text(AppText.actionReset))
    }
}
