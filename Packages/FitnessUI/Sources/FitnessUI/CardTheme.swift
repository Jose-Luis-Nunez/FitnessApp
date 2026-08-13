import SwiftUI

/// Bundles a card's visual surface style with the content colors that work on
/// that surface. Static presets guarantee that title/subtitle colors are always
/// readable against the chosen background.
public struct CardTheme {
    public let surface: CardSurfaceStyle
    public let titleColor: Color
    public let subtitleColor: Color
    public let titleFont: Font

    public init(
        surface: CardSurfaceStyle,
        titleColor: Color,
        subtitleColor: Color,
        titleFont: Font = AppStyle.Font.cardHeadline
    ) {
        self.surface = surface
        self.titleColor = titleColor
        self.subtitleColor = subtitleColor
        self.titleFont = titleFont
    }
}

extension CardTheme {
    public static let idle = CardTheme(
        surface: .primary,
        titleColor: AppStyle.Color.idleTitle,
        subtitleColor: AppStyle.Color.idleMetricLabel,
        titleFont: AppStyle.Font.idleCardTitle
    )

    public static let completed = CardTheme(
        surface: .glass(AppStyle.Color.exerciseCardBackground),
        titleColor: Color.white,
        subtitleColor: Color.white.opacity(0.7)
    )

    /// Completed exercise card on the same neutral `.primary` surface as
    /// `IdleActiveCardModelView`, with matching headline / secondary text colors.
    /// Callers resolve a completion `EdgeIndicator` from `AppColorTheme` at
    /// render time so the value cannot retain an obsolete accent palette.
    public static let inactiveOnIdle = CardTheme(
        surface: .primary,
        titleColor: AppStyle.Color.idleTitle,
        subtitleColor: AppStyle.Color.idleMetricLabel,
        titleFont: AppStyle.Font.idleCardTitle
    )
}
