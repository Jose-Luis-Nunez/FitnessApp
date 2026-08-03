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
    static var outlineColor: Color {
        AppStyle.Color.gray.opacity(0.7)
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
