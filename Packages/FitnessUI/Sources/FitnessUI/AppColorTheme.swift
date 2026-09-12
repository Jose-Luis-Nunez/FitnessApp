import SwiftUI

/// Immutable, observable-by-value color theme injected once at the app root.
///
/// SwiftUI invalidates only environment consumers when this value changes, so
/// feature identity, local state, navigation, requests and view models survive
/// an accent switch.
public struct AppColorTheme: Sendable {
    public let scheme: AppAccentScheme
    public let accent: AccentPalette
    public let profile: ProfileColorTheme
    /// Which default muscle figures to draw. Carried here, next to the accent,
    /// so every artwork consumer reads one environment value — but chosen
    /// independently of the scheme.
    public let muscleIcons: MuscleIconStyle

    public init(scheme: AppAccentScheme, muscleIcons: MuscleIconStyle = .standard) {
        self.scheme = scheme
        accent = scheme.palette
        profile = ProfileColorTheme(colorScheme: scheme)
        self.muscleIcons = muscleIcons
    }

    /// Asset name for a category's default figure in the chosen icon style.
    public func muscleIconName(for icon: String) -> String {
        muscleIcons.iconName(for: icon)
    }

    /// Track behind a progress bar's unfilled part. The grey default figures
    /// are neutral, so the track beside them goes neutral too (the grey
    /// palette's track) instead of the accent's dark tint. The fill keeps
    /// the accent. Change the pairing here, not in the bar.
    public var progressTrack: Color {
        muscleIcons == .standard ? AccentPalette.grey.progressTrack : accent.progressTrack
    }

    /// Soft halo behind a category tile's figure. A neutral grey with the
    /// standard figures, so no green shimmer sits behind a grey body; the
    /// accent's dark tone with the coloured ones.
    public var artworkHalo: Color {
        muscleIcons == .standard ? AppStyle.Color.artworkHaloNeutral : accent.black
    }

    public static let green = AppColorTheme(scheme: .green)
    public static let grey = AppColorTheme(scheme: .grey)
}

private struct AppColorThemeKey: EnvironmentKey {
    static let defaultValue = AppColorTheme.green
}

public extension EnvironmentValues {
    var appColorTheme: AppColorTheme {
        get { self[AppColorThemeKey.self] }
        set { self[AppColorThemeKey.self] = newValue }
    }
}

public extension View {
    /// Injects a deterministic app theme for a subtree, preview or test.
    func appColorTheme(
        _ scheme: AppAccentScheme,
        muscleIcons: MuscleIconStyle = .standard
    ) -> some View {
        environment(\.appColorTheme, AppColorTheme(scheme: scheme, muscleIcons: muscleIcons))
    }
}
