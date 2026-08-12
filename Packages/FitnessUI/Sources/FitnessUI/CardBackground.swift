import SwiftUI

public enum CardSurfaceStyle {
    case glass(Color)
    case gradient(Color)
    case primary
}

public struct CardBackground<Content: View>: View {
    public typealias Style = CardSurfaceStyle

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
            Color.clear
                .appDarkSurface(
                    backgroundColor: backgroundColor,
                    in: .rect(cornerRadius: AppStyle.CornerRadius.card)
                )
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
        case .primary:
            LinearGradient(
                gradient: Gradient(colors: [
                    AppStyle.Color.idleCardSoft,
                    AppStyle.Color.idleCardBackground,
                    AppStyle.Color.idleCardDark,
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
        case .primary:
            ZStack {
                RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [AppStyle.Color.idleCardInnerGlow, .clear],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )

                RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [AppStyle.Color.idleCardBorderLight, AppStyle.Color.idleCardBorderDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: AppStyle.Layout.idleCardBorderWidth
                    )
            }
        }
    }
}
