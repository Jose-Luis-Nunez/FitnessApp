import SwiftUI

/// Fallback when `glassEffect` is unavailable (package supports macOS 14 / iOS 17).
enum TrainingGlassEffectCompat {
    @ViewBuilder
    static func rectCard(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            Color.clear.glassEffect(in: .rect(cornerRadius: cornerRadius))
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    static func roundedRectangleContinuous(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.clear)
                .glassEffect()
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    static func roundedFrameGlass(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.clear)
                .frame(width: width, height: height)
                .glassEffect()
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .frame(width: width, height: height)
        }
    }

    @ViewBuilder
    static func circleGlass() -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            Circle()
                .fill(Color.clear)
                .glassEffect()
        } else {
            Circle()
                .fill(.ultraThinMaterial)
        }
    }
}
