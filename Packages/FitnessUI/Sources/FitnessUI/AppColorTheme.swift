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

    public init(scheme: AppAccentScheme) {
        self.scheme = scheme
        accent = scheme.palette
        profile = ProfileColorTheme(colorScheme: scheme)
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
    func appColorTheme(_ scheme: AppAccentScheme) -> some View {
        environment(\.appColorTheme, AppColorTheme(scheme: scheme))
    }
}
