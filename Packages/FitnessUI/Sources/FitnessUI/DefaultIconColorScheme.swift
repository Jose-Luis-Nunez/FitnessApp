import Foundation

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
}
