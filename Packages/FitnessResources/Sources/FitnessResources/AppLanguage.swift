import Foundation

public struct AppLanguage: RawRepresentable, CaseIterable, Codable, Sendable,
    Hashable, Identifiable
{
    public static let storageKey = "appLanguage"
    public static let english = AppLanguage(unchecked: "en")
    public static let german = AppLanguage(unchecked: "de")

    public let rawValue: String

    public init?(rawValue: String) {
        let identifier = Self.normalizedIdentifier(rawValue)
        guard Self.supportedLanguageCodes.contains(identifier) else {
            return nil
        }
        self.init(unchecked: identifier)
    }

    public var id: String { rawValue }

    public var locale: Locale {
        let identifier = Locale.Language(identifier: rawValue)
            .maximalIdentifier
            .replacingOccurrences(of: "-", with: "_")
        return Locale(identifier: identifier)
    }

    /// The language name written in that language, for example “Deutsch”.
    public var autonym: String {
        Locale(identifier: rawValue).localizedString(forIdentifier: rawValue)
            ?? rawValue
    }

    /// Languages offered by the picker come from the String Catalog bundle.
    /// Adding a catalog localization therefore requires no Swift change here.
    public static var allCases: [AppLanguage] {
        supportedLanguageCodes
            .map(AppLanguage.init(unchecked:))
            .sorted { lhs, rhs in
                if lhs == .english { return true }
                if rhs == .english { return false }
                return lhs.autonym.localizedStandardCompare(rhs.autonym) == .orderedAscending
            }
    }

    public static func resolving(languageCode: String?) -> AppLanguage {
        languageCode.flatMap(AppLanguage.init(rawValue:)) ?? .english
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = AppLanguage(rawValue: rawValue) ?? .english
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    private static let supportedLanguageCodes = languageCodes(
        in: Bundle.module.localizations
    )

    static func languageCodes(in localizations: [String]) -> Set<String> {
        var identifiers = Set<String>(localizations.compactMap { localization -> String? in
            guard localization != "Base" else { return nil }
            return normalizedIdentifier(localization)
        })
        identifiers.insert(english.rawValue)
        return identifiers
    }

    private init(unchecked rawValue: String) {
        self.rawValue = rawValue
    }

    private static func normalizedIdentifier(_ identifier: String) -> String {
        identifier.replacingOccurrences(of: "_", with: "-")
    }
}
