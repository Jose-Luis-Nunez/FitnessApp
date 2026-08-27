import SwiftUI
import FitnessUI

/// Shape helpers for training controls using FitnessUI's shared cross-version
/// surface treatment.
enum TrainingGlassEffectCompat {
    @ViewBuilder
    static func rectCard(cornerRadius: CGFloat) -> some View {
        Color.clear
            .appGlassEffect(in: .rect(cornerRadius: cornerRadius))
    }

    @ViewBuilder
    static func roundedRectangleContinuous(cornerRadius: CGFloat) -> some View {
        Color.clear
            .appDarkSurface(
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
    }
}

/// Shared flat chrome for controls that visually belong to the active-set
/// timer. Keeping the surface package-internal prevents the timer and action
/// buttons from drifting to subtly different outline treatments.
enum TrainingControlSurfaceStyle {
    /// Same value as the ring around the idle card's play button and as the
    /// home bottom menu bar's outline, so all of the app's floating chrome
    /// reads as one treatment. Previously dimmed to 70%, which made these
    /// outlines a shade fainter than the ring.
    static var outlineColor: Color {
        AppStyle.Color.controlOutline
    }

    @ViewBuilder
    static func surface<S: Shape>(in shape: S) -> some View {
        shape
            .fill(Color.clear)
            .overlay {
                shape.stroke(
                    outlineColor,
                    lineWidth: AppStyle.Layout.darkSurfaceOutlineWidth
                )
            }
    }
}
