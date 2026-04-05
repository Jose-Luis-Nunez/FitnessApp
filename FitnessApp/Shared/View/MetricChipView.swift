import SwiftUI

struct MetricChipView<Content: View>: View {
    var width: CGFloat? = nil
    var height: CGFloat = 68
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(width: width, height: height)
            .background(AppStyle.Color.metricChipBackground)
            .cornerRadius(AppStyle.CornerRadius.defaultButton)
            .overlay(
                RoundedRectangle(cornerRadius: AppStyle.CornerRadius.defaultButton)
                    .stroke(AppStyle.Color.gray.opacity(0.7), lineWidth: 1)
            )
    }
}
