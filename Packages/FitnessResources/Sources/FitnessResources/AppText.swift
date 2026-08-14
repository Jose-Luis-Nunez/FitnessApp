import Foundation

/// Public namespace for the localization symbols generated from the String
/// Catalog at build time. Text content lives only in `Localizable.xcstrings`.
public enum AppText {
    static let bundle: LocalizedStringResource.BundleDescription =
        .atURL(Bundle.module.bundleURL)

    public static func resolve(
        _ resource: LocalizedStringResource,
        locale: Locale
    ) -> String {
        var localized = resource
        localized.locale = locale
        return String(localized: localized)
    }
}
