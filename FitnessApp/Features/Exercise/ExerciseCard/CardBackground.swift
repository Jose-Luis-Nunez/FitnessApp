import SwiftUI

struct CardBackground<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppStyle.Padding.card)
            .frame(maxWidth: .infinity)
            .background(AppStyle.Color.exerciseCardBackground)
            .cornerRadius(AppStyle.CornerRadius.card)
    }
}
