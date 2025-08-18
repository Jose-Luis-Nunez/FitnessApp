import SwiftUI

struct CardBackground<Content: View>: View {
    let content: Content
    let backgroundColor: Color
    let useGlassEffect: Bool
    let addPadding: Bool
    
    init(
        backgroundColor: Color = AppStyle.Color.exerciseCardBackground,
        useGlassEffect: Bool = false,
        addPadding: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.backgroundColor = backgroundColor
        self.useGlassEffect = useGlassEffect
        self.addPadding = addPadding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(addPadding ? AppStyle.Padding.card : 0)
            .frame(maxWidth: .infinity)
            .background(
                Group {
                    if useGlassEffect {
                        if #available(iOS 26.0, *) {
                            Color.clear
                                .glassEffect(in: .rect(cornerRadius: AppStyle.CornerRadius.card))
                        } else if #available(iOS 18.0, *) {
                            LiquidGlassBackground(
                                cornerRadius: AppStyle.CornerRadius.card,
                                material: .ultraThinMaterial,
                                tintOpacity: 0.0,
                                showsEdgeStroke: false,
                                showsCaustic: false,
                                shadowOpacity: 0.0,
                                lightnessBoostOpacity: 0.0
                            )
                        } else {
                            backgroundColor
                        }
                    } else {
                        ZStack {
                            backgroundColor.opacity(0.85)
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.clear,
                                    Color.white.opacity(0.02),
                                    Color.clear,
                                    Color.white.opacity(0.02),
                                    Color.clear,
                                ]),
                                startPoint: .bottomLeading,
                                endPoint: .topTrailing
                            )
                        }
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card, style: .continuous))
            .overlay(
                useGlassEffect ? nil : 
                RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card, style: .continuous)
                    .stroke(AppStyle.Color.exerciseCardBackground.opacity(0.03), lineWidth: 1.5)
                    .blur(radius: 0.6)
            )
          
    }
}
