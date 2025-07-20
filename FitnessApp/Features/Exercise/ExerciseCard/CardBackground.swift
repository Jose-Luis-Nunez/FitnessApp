import SwiftUI

struct CardBackground<Content: View>: View {
    let content: Content
    let backgroundColor: Color
    
    init(
        backgroundColor: Color = AppStyle.Color.exerciseCardBackground,
        @ViewBuilder content: () -> Content
    ) {
        self.backgroundColor = backgroundColor
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(AppStyle.Padding.card)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    backgroundColor.opacity(0.85)
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.03),
                            Color.clear,
                            Color.white.opacity(0.03)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card, style: .continuous)
                    .stroke(AppStyle.Color.exerciseCardBackground.opacity(0.03), lineWidth: 1.5)
                    .blur(radius: 0.6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card, style: .continuous)
                    .stroke(Color.white.opacity(0.03), lineWidth: 1)
            )
    }
}
