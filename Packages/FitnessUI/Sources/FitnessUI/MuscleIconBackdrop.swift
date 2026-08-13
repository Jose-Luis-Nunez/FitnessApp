import SwiftUI

/// Decorative backdrop behind a body-icon preview: a faint concentric field of
/// dots inside a thin ring, fading toward the edges. Purely cosmetic. Shared by
/// the exercise picker header and the new-workout gallery.
public struct MuscleIconBackdrop: View {
    @Environment(\.appColorTheme) private var appColorTheme

    private var tint: Color { appColorTheme.accent.light }

    public init() {}

    public var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let ringDiameter = side * 0.92

            ZStack {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let maxRadius = ringDiameter / 2
                    let ringCount = 7
                    for ring in 1...ringCount {
                        let radius = maxRadius * CGFloat(ring) / CGFloat(ringCount)
                        let dotCount = max(8, ring * 7)
                        for i in 0..<dotCount {
                            let angle = (2 * Double.pi) * Double(i) / Double(dotCount)
                            let point = CGPoint(
                                x: center.x + radius * CGFloat(cos(angle)),
                                y: center.y + radius * CGFloat(sin(angle))
                            )
                            let dotSize: CGFloat = 1.6
                            let rect = CGRect(
                                x: point.x - dotSize / 2,
                                y: point.y - dotSize / 2,
                                width: dotSize,
                                height: dotSize
                            )
                            context.fill(Path(ellipseIn: rect), with: .color(tint.opacity(0.55)))
                        }
                    }
                }

                Circle()
                    .stroke(tint.opacity(0.5), lineWidth: 1)
                    .frame(width: ringDiameter, height: ringDiameter)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .mask(
                RadialGradient(
                    gradient: Gradient(colors: [Color.white, Color.white.opacity(0)]),
                    center: .center,
                    startRadius: side * 0.2,
                    endRadius: side * 0.62
                )
            )
        }
    }
}
