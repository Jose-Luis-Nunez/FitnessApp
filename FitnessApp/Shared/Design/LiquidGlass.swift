import SwiftUI

/// A reusable liquid glass background with specular highlights, soft edge light, and inner shadow.
struct LiquidGlassBackground: View {
    let cornerRadius: CGFloat
    let material: Material
    let tintOpacity: Double
    let showsEdgeStroke: Bool
    let showsCaustic: Bool
    let shadowOpacity: Double
    let lightnessBoostOpacity: Double

    init(
        cornerRadius: CGFloat,
        material: Material = .ultraThinMaterial,
        tintOpacity: Double = 0.08,
        showsEdgeStroke: Bool = true,
        showsCaustic: Bool = true,
        shadowOpacity: Double = 0.40,
        lightnessBoostOpacity: Double = 0.0
    ) {
        self.cornerRadius = cornerRadius
        self.material = material
        self.tintOpacity = tintOpacity
        self.showsEdgeStroke = showsEdgeStroke
        self.showsCaustic = showsCaustic
        self.shadowOpacity = shadowOpacity
        self.lightnessBoostOpacity = lightnessBoostOpacity
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        // Break the composition into smaller overlays to help the type-checker
        let base = shape.fill(material)
        let tint = shape.fill(Color.black.opacity(tintOpacity)).blendMode(.multiply)
        let boost = shape.fill(Color.white.opacity(lightnessBoostOpacity)).blendMode(.screen)
        let stroke = shape.stroke(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.28),
                    Color.white.opacity(0.10),
                    Color.black.opacity(0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            lineWidth: 1
        )
        let caustic = Circle()
            .fill(
                RadialGradient(
                    colors: [Color.white.opacity(0.12), Color.white.opacity(0.03), .clear],
                    center: .center,
                    startRadius: 2,
                    endRadius: cornerRadius
                )
            )
            .frame(width: cornerRadius * 1.2, height: cornerRadius * 0.9)
            .blur(radius: 18)
            .opacity(0.45)
            .offset(x: cornerRadius * 0.6, y: -cornerRadius * 0.55)

        return base
            .overlay(tint)
            .overlay(lightnessBoostOpacity > 0 ? AnyView(boost) : AnyView(EmptyView()))
            .overlay(showsEdgeStroke ? AnyView(stroke) : AnyView(EmptyView()))
            .overlay(showsCaustic ? AnyView(caustic) : AnyView(EmptyView()))
            .shadow(color: .black.opacity(shadowOpacity), radius: 20, x: 0, y: 10)
    }
}
