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

    @ViewBuilder
    static func circleGlass() -> some View {
        Color.clear
            .appDarkSurface(in: Circle())
    }
}
