import SwiftUI
import FitnessResources

/// Which set of default muscle figures the app draws. Independent of
/// ``AppAccentScheme``: the accent colours the chrome, this picks the artwork,
/// so a user can pair either palette with either figure set.
///
/// - `standard`: the neutral "grey_" figures — the app's default.
/// - `colored`: the tinted originals.
///
/// Exercise-specific artwork has no alternate asset and passes through
/// unchanged in both styles.
public enum MuscleIconStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case standard
    case colored

    public var id: String { rawValue }

    /// Compatibility boundary for the persisted preference; do not rename.
    public static let storageKey = "muscleIconStyle"

    /// Shown as a yes/no answer to "Default icons" in the profile.
    public var localizedName: LocalizedStringResource {
        switch self {
        case .standard: return AppText.commonYes
        case .colored: return AppText.commonNo
        }
    }

    /// Resolves the asset name for a default category icon.
    public func iconName(for icon: String) -> String {
        guard self == .standard, icon.hasPrefix("default") else { return icon }
        return "grey_\(icon)"
    }
}
