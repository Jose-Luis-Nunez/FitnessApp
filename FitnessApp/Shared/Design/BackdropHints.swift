import SwiftUI

/// Decorative gradient blobs placed BEHIND a glass surface to give the material
/// something colorful/bright to refract. Without backdrop variation, glass wirkt milchig.
struct BackdropHints: View {
    let barWidth: CGFloat
    let barHeight: CGFloat

    var body: some View {
        ZStack {
            // Bright highlight behind the left/center to amplify refraction
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.45),
                            Color.white.opacity(0.14),
                            .clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: max(barWidth, barHeight)
                    )
                )
                .frame(width: barHeight * 2.8, height: barHeight * 2.4)
                .blur(radius: 50)
                .offset(x: -barWidth * 0.25, y: -barHeight * 0.65)

            // Darker blob on the right for contrast/shape
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.black.opacity(0.30),
                            Color.black.opacity(0.10),
                            .clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: max(barWidth, barHeight)
                    )
                )
                .frame(width: barHeight * 2.6, height: barHeight * 2.2)
                .blur(radius: 52)
                .offset(x: barWidth * 0.30, y: -barHeight * 0.55)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}


