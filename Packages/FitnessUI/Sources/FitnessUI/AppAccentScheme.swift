import SwiftUI
import FitnessResources

/// User-selectable accent scheme for the whole app.
///
/// The raw values and storage key intentionally preserve the format used by
/// existing installations. Persistence is owned by the app root; feature and
/// shared views consume the resolved ``AppColorTheme`` from the environment.
public enum AppAccentScheme: String, CaseIterable, Identifiable, Codable, Sendable {
    case green
    case grey

    public var id: String { rawValue }

    /// Compatibility boundary for the persisted preference. The key must not
    /// change when the type or the user-facing label changes.
    public static let storageKey = "defaultIconColorScheme"

    public var localizedName: LocalizedStringResource {
        switch self {
        case .green: return AppText.profileAccentGreen
        case .grey: return AppText.profileAccentGrey
        }
    }

    /// Resolves the asset name for a default category icon. Exercise-specific
    /// artwork has no alternate asset and therefore passes through unchanged.
    public func iconName(for icon: String) -> String {
        guard self == .grey, icon.hasPrefix("default") else { return icon }
        return "grey_\(icon)"
    }

    public var palette: AccentPalette {
        switch self {
        case .green: return .green
        case .grey: return .grey
        }
    }
}
