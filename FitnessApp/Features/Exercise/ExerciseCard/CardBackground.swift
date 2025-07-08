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
            .background(backgroundColor)
            .cornerRadius(AppStyle.CornerRadius.card)
    }
}
