import SwiftUI

/// Semantic colors for the profile family of screens.
///
/// Feature views consume roles instead of concrete palette names. The app root
/// injects the value from the persisted accent preference, which makes theme
/// changes observable through SwiftUI's environment and keeps previews and
/// snapshots deterministic.
public struct ProfileColorTheme: Sendable {
    public let title: Color
    public let secondary: Color
    public let accent: Color
    public let accentFill: Color
    public let onAccent: Color
    public let innerBackground: Color
    public let innerStroke: Color
    public let inputBackground: Color
    public let divider: Color

    public init(colorScheme: DefaultIconColorScheme) {
        let palette = colorScheme.palette
        title = AppStyle.Color.idleTitle
        secondary = AppStyle.Color.idleMetricLabel
        accent = palette.idleMetricValue
        accentFill = palette.idleAccentFill
        onAccent = AppStyle.Color.backgroundColor
        innerBackground = AppStyle.Color.idleCardBackground
        innerStroke = Color.white.opacity(AppStyle.Opacity.subtleStroke)
        inputBackground = AppStyle.Color.sheetInputBackground
        divider = AppStyle.Color.idleDivider
    }

    public static let green = ProfileColorTheme(colorScheme: .green)
    public static let grey = ProfileColorTheme(colorScheme: .grey)
}

private struct ProfileColorThemeKey: EnvironmentKey {
    static let defaultValue = ProfileColorTheme.green
}

public extension EnvironmentValues {
    var profileColorTheme: ProfileColorTheme {
        get { self[ProfileColorThemeKey.self] }
        set { self[ProfileColorThemeKey.self] = newValue }
    }
}

public extension View {
    /// Injects a deterministic profile theme for an app subtree, preview, or test.
    func profileColorTheme(_ theme: ProfileColorTheme) -> some View {
        environment(\.profileColorTheme, theme)
    }

    /// Standard profile-card padding, minimum height, and idle-card surface.
    func profileCardSurface(
        minHeight: CGFloat = AppStyle.Layout.profileCardCollapsedMinHeight
    ) -> some View {
        modifier(ProfileCardSurfaceModifier(minHeight: minHeight))
    }

    /// Read-only nested surface shared by profile metrics and transit results.
    func profileReadOnlyTileSurface(
        cornerRadius: CGFloat = AppStyle.CornerRadius.tile
    ) -> some View {
        modifier(ProfileReadOnlyTileSurfaceModifier(cornerRadius: cornerRadius))
    }
}

/// Standard profile card composition. Its visual surface is exactly the
/// training idle-card surface while its content layout remains caller-owned.
public struct ProfileCardContainer<Content: View>: View {
    private let minHeight: CGFloat
    private let content: Content

    public init(
        minHeight: CGFloat = AppStyle.Layout.profileCardCollapsedMinHeight,
        @ViewBuilder content: () -> Content
    ) {
        self.minHeight = minHeight
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .profileCardSurface(minHeight: minHeight)
    }
}

private struct ProfileCardSurfaceModifier: ViewModifier {
    let minHeight: CGFloat

    func body(content: Content) -> some View {
        CardBackground(style: .idle, addPadding: false) {
            content
                .padding(AppStyle.Padding.card)
                .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        }
    }
}

private struct ProfileReadOnlyTileSurfaceModifier: ViewModifier {
    @Environment(\.profileColorTheme) private var theme
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(theme.innerBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        theme.innerStroke,
                        lineWidth: AppStyle.Layout.profileSurfaceBorderWidth
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
