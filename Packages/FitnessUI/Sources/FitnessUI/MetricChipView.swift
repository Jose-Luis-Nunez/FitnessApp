import SwiftUI

public struct MetricChipView<Content: View>: View {
    public var width: CGFloat?
    public var height: CGFloat = 68
    @ViewBuilder public let content: () -> Content

    public init(width: CGFloat? = nil, height: CGFloat = 68, @ViewBuilder content: @escaping () -> Content) {
        self.width = width
        self.height = height
        self.content = content
    }

    public var body: some View {
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
