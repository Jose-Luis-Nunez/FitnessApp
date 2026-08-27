import SwiftUI

public enum CardSurfaceStyle {
    case plain
    case glass(Color)
    case gradient(Color)
    case primary
    /// Like `primary`, but with the opaque gradient fill replaced by a barely
    /// there wash, so a screen-level backdrop reads through the card. Keeps the
    /// same border and corner radius, so a translucent card still sits in the
    /// same visual family as its opaque siblings.
    case translucent
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

    @ViewBuilder
    public var body: some View {
        switch style {
        case .plain:
            paddedContent
        case .primary:
            paddedContent
                .appPrimarySurface(
                    in: RoundedRectangle(
                        cornerRadius: AppStyle.CornerRadius.card,
                        style: .continuous
                    )
                )
        case .translucent:
            paddedContent
                .appTranslucentSurface(
                    in: RoundedRectangle(
                        cornerRadius: AppStyle.CornerRadius.card,
                        style: .continuous
                    )
                )
        case .glass, .gradient:
            paddedContent
                .background(backgroundView)
                .clipShape(RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card, style: .continuous))
                .overlay(strokeOverlay)
        }
    }

    private var paddedContent: some View {
        content
            .padding(addPadding ? AppStyle.Padding.card : 0)
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .plain:
            EmptyView()
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
        case .primary, .translucent:
            EmptyView()
        }
    }

    @ViewBuilder
    private var strokeOverlay: some View {
        switch style {
        case .plain:
            EmptyView()
        case .glass:
            EmptyView()
        case .gradient:
            RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card, style: .continuous)
                .stroke(AppStyle.Color.exerciseCardBackground.opacity(0.03), lineWidth: 1.5)
                .blur(radius: 0.6)
        case .primary, .translucent:
            EmptyView()
        }
    }
}

public extension View {
    /// Applies the translucent card treatment to any insettable shape: the same
    /// border and clip as `appPrimarySurface`, but **no fill at all**, so
    /// whatever the screen puts behind the card — e.g. `AmbientScreenBackground`
    /// — shows through unchanged and only the hairline defines the card.
    ///
    /// Deliberately not a low-opacity white wash: over a near-black backdrop an
    /// additive wash lightens the card into a grey panel instead of making it
    /// transparent, which is the opposite of the intent.
    ///
    /// Use this only on screens that actually carry a backdrop worth showing —
    /// over a flat colour the card loses all separation but its border.
    func appTranslucentSurface<S: InsettableShape>(in shape: S) -> some View {
        overlay {
            shape.strokeBorder(
                LinearGradient(
                    colors: [AppStyle.Color.idleCardBorderLight, AppStyle.Color.idleCardBorderDark],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: AppStyle.Layout.idleCardBorderWidth
            )
        }
        .clipShape(shape)
    }

    /// Applies the neutral primary card treatment to any insettable shape.
    /// Profile cards, category tiles, and compact navigation controls share
    /// this surface while retaining their own rectangle, capsule, or circle.
    func appPrimarySurface<S: InsettableShape>(in shape: S) -> some View {
        background {
            shape.fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        AppStyle.Color.idleCardSoft,
                        AppStyle.Color.idleCardBackground,
                        AppStyle.Color.idleCardDark,
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .overlay {
            ZStack {
                shape.fill(
                    RadialGradient(
                        colors: [AppStyle.Color.idleCardInnerGlow, .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 200
                    )
                )

                shape.strokeBorder(
                    LinearGradient(
                        colors: [AppStyle.Color.idleCardBorderLight, AppStyle.Color.idleCardBorderDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: AppStyle.Layout.idleCardBorderWidth
                )
            }
        }
        .clipShape(shape)
    }
}
