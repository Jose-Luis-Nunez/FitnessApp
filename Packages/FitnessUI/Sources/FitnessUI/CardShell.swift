import SwiftUI

/// Structural card wrapper that standardizes header layout, spacing, shadow,
/// and padding across all standard cards. Builds on `CardBackground` for the
/// visual surface and `CardTheme` for content colors.
///
/// Two content slots:
/// - `titleContent`: Rendered inside the header HStack, between `leading` and
///   `trailing`. Typically contains the card title and a subtitle or metric row.
/// - `expandedContent`: Rendered below the header in the outer VStack. Used for
///   conditionally visible sections (weight phases, set tiles, etc.). Defaults
///   to `EmptyView`.
///
/// Cards that don't fit this slot pattern (e.g. `ActiveCardModelView` with its
/// ZStack and protruding icon) should use `CardBackground` directly.
public struct CardShell<
    Leading: View,
    TitleContent: View,
    Trailing: View,
    ExpandedContent: View,
    ContentBackground: View
>: View {
    public let theme: CardTheme
    public let edgeIndicator: EdgeIndicator?
    let leading: Leading
    let titleContent: TitleContent
    let trailing: Trailing
    let expandedContent: ExpandedContent
    let contentBackground: ContentBackground

    public init(
        theme: CardTheme,
        edgeIndicator: EdgeIndicator? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() },
        @ViewBuilder titleContent: () -> TitleContent,
        @ViewBuilder expandedContent: () -> ExpandedContent = { EmptyView() },
        @ViewBuilder contentBackground: () -> ContentBackground = { EmptyView() }
    ) {
        self.theme = theme
        self.edgeIndicator = edgeIndicator
        self.leading = leading()
        self.trailing = trailing()
        self.titleContent = titleContent()
        self.expandedContent = expandedContent()
        self.contentBackground = contentBackground()
    }

    public var body: some View {
        CardBackground(style: theme.surface, addPadding: false) {
            VStack(spacing: 0) {
                HStack(spacing: AppStyle.Layout.cardHeaderSpacing) {
                    leading

                    titleContent

                    Spacer(minLength: 4)

                    trailing
                }
                .padding(.horizontal, AppStyle.Padding.card)

                expandedContent
            }
            .padding(.vertical, AppStyle.Padding.cardVertical)
            .background { contentBackground }
            .background(alignment: .leading) {
                if let indicator = edgeIndicator {
                    indicator.color
                        .frame(width: indicator.width)
                }
            }
        }
        .padding(.horizontal, AppStyle.Padding.card)
        .shadow(
            color: AppStyle.Shadow.cardColor,
            radius: AppStyle.Shadow.cardRadius,
            x: 0,
            y: AppStyle.Shadow.cardY
        )
    }
}

/// Colored strip rendered at the leading edge of a card, visible through the
/// card's clip shape. Used for completion indicators, progress bars, etc.
public struct EdgeIndicator {
    public let color: Color
    public let width: CGFloat

    public init(color: Color, width: CGFloat) {
        self.color = color
        self.width = width
    }

    public static let completed = EdgeIndicator(
        color: AppStyle.Color.greenGlow,
        width: AppStyle.Layout.completedBarWidth
    )
}
