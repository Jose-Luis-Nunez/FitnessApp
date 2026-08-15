import SwiftUI

/// Structural card wrapper that standardizes header layout, spacing, and
/// padding across exercise rows. `CardTheme` decides whether the structure is
/// frameless or receives a visual surface.
///
/// Content slots (left to right in the header HStack):
/// - `leading`: Left edge — typically a category icon or selection control.
/// - `titleContent`: Center area — title, subtitle, metric row.
/// - `trailing`: Right edge — typically the play button or checkmark. Defaults
///   to `EmptyView`.
/// - `expandedContent`: Rendered below the header. Defaults to `EmptyView`.
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

                    // `titleContent` carries `.frame(maxWidth: .infinity)`, so it
                    // claims the slack between leading and trailing and pins the
                    // trailing control to the right edge (no competing Spacer,
                    // which would otherwise split the slack and leave the title
                    // content short of the trailing control).
                    titleContent

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

}
