import SwiftUI

public struct CardBackground<Content: View>: View {
    public enum Style {
        case glass(Color)
        case gradient(Color)
    }

    public let content: Content
    public let style: Style
    public let addPadding: Bool

    public init(
        style: Style = .gradient(AppStyle.Color.exerciseCardBackground),
        addPadding: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.addPadding = addPadding
        self.content = content()
    }

    public init(
        backgroundColor: Color = AppStyle.Color.exerciseCardBackground,
        useGlassEffect: Bool = false,
        addPadding: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        if useGlassEffect {
            self.style = .glass(backgroundColor)
        } else {
            self.style = .gradient(backgroundColor)
        }
        self.addPadding = addPadding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(addPadding ? AppStyle.Padding.card : 0)
            .frame(maxWidth: .infinity)
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card, style: .continuous))
            .overlay(strokeOverlay)
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .glass(let backgroundColor):
            ZStack {
                backgroundColor
                if #available(iOS 26.0, macOS 26.0, *) {
                    Color.clear
                        .glassEffect(in: .rect(cornerRadius: AppStyle.CornerRadius.card))
                } else {
                    RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
        case .gradient(let backgroundColor):
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

    @ViewBuilder
    private var strokeOverlay: some View {
        switch style {
        case .glass:
            EmptyView()
        case .gradient:
            RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card, style: .continuous)
                .stroke(AppStyle.Color.exerciseCardBackground.opacity(0.03), lineWidth: 1.5)
                .blur(radius: 0.6)
        }
    }
}

