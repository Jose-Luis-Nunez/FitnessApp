import SwiftUI

/// User-selectable color scheme for the *default* category icons.
///
/// Only the generic `defaultXxxIcon` images ship in two variants:
/// `green` (the original assets) and `grey` (the `grey_`-prefixed assets).
/// Specific exercise icons (`bicepsIcon`, …) have no grey variant and pass
/// through unchanged. Persisted under ``storageKey`` via `@AppStorage`, so the
/// Profile picker and every icon render site read the same value.
public enum DefaultIconColorScheme: String, CaseIterable, Identifiable, Codable, Sendable {
    case green
    case grey

    public var id: String { rawValue }

    /// Shared `@AppStorage` key used by the Profile picker and the card views.
    public static let storageKey = "defaultIconColorScheme"

    /// Label shown in the Profile picker.
    public var displayName: String {
        switch self {
        case .green: return "Green"
        case .grey:  return "Grey"
        }
    }

    /// Resolves the asset name for `icon` under this scheme. Default category
    /// icons map to their `grey_` variant when `.grey` is selected; all other
    /// icons are returned unchanged.
    public func iconName(for icon: String) -> String {
        guard self == .grey, icon.hasPrefix("default") else { return icon }
        return "grey_\(icon)"
    }

    /// Fill color for the category progress bar under this scheme.
    /// `.green` keeps the canonical `greenGlow`; `.grey` switches to
    /// `progressOrange`. Only the fill is themed — the track color and the
    /// "X of Y" text are scheme-independent.
    public var progressFillColor: Color {
        switch self {
        case .green: return AppStyle.Color.greenGlow
        case .grey:  return AppStyle.Color.progressOrange
        }
    }

    /// Track (empty portion) color for the category progress bar under this
    /// scheme. `.green` keeps the teal `progressTrack`; `.grey` switches to the
    /// neutral `progressTrackGrey` so the empty bar matches the grey theme.
    public var progressTrackColor: Color {
        switch self {
        case .green: return AppStyle.Color.progressTrack
        case .grey:  return AppStyle.Color.progressTrackGrey
        }
    }

    /// Current scheme read from persistent storage — the same key `@AppStorage`
    /// writes. Lets non-`@AppStorage` contexts (notably the static
    /// `AppStyle.Color` accent palette) resolve the active scheme.
    public static var current: DefaultIconColorScheme {
        UserDefaults.standard.string(forKey: storageKey)
            .flatMap(DefaultIconColorScheme.init(rawValue:)) ?? .green
    }

    /// The accent ("green") color family for this scheme. `.green` returns the
    /// original palette (visually unchanged); `.grey` returns the warm orange
    /// palette so the grey design has no leftover green accents.
    public var palette: AccentPalette {
        switch self {
        case .green: return .green
        case .grey:  return .grey
        }
    }
}
