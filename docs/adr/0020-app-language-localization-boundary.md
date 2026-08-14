# 0020 — App language and localization boundary

* Status: accepted
* Date: 2026-08-13
* Deciders: jose.nunez
* Complements: ADR-0019

## Context

The app previously rendered English literals and several German-specific date
formatters directly in feature views and view models. A runtime language change
must update the complete visible interface without replacing the SwiftUI tree,
resetting navigation, dismissing sheets, discarding form input or restarting
feature work.

## Options

- **A — Rebuild the root using `.id(language)`:** simple invalidation, but
  destroys feature-owned state.
- **B — Add a mutable global settings store:** observable, but creates a shared
  owner for unrelated preferences.
- **C — Persist at the composition root and propagate `Locale` by value:** use
  typed catalog resources at presentation boundaries and explicit locale or
  language parameters outside SwiftUI.

## Decision

Choose **Option C**.

`FitnessAppApp` is the sole owner of `@AppStorage(AppLanguage.storageKey)`.
`AppLanguage` lives in `FitnessResources`, preserves BCP-47 language codes as
its persisted raw values and defaults to English. Its picker choices and locale
mapping are derived from the localizations bundled with the central String
Catalog, so adding a catalog localization does not require another Swift enum
case. The app injects the selected locale at its visual root through
`EnvironmentValues.locale`.
There is no language-specific environment key, global settings store or
identity refresh.

`FitnessResources` owns the only English-source String Catalog. A package build
tool invokes Xcode's `xcstringstool generate-symbols` and exposes those symbols
through the public `AppText` namespace because SwiftPM's native generated
catalog symbols are not public across package boundaries.
The generated file is build output and is never edited or checked in. Existing
English wording is the source and fallback contract; translations are maintained
only in the catalog. Static entries generate properties. Only entries with
interpolation or plural operands generate functions, mirroring Xcode's native
symbol model rather than introducing hand-written formatting APIs.

Feature view models expose semantic states and structured values. Views resolve
localized labels at render time; user-provided names remain verbatim. Visible
dates and numbers use the environment locale. Parsers and network decoders keep
their technical locale contracts, including `en_US_POSIX` where required.

`FitnessTraining` owns the Live Activity content-state payload while the app's
ActivityKit attributes expose it through their nested `ContentState` type alias.
The payload carries an optional language code. Missing and unknown values
resolve to English so older payloads remain decodable. The widget follows that
content language; static intent metadata follows the system localization. The
app target links the same physical central catalog for Apple's App Intent
metadata extraction; it does not own a second catalog file.

## Consequences

- **Positive:** Language changes preserve view identity, navigation, sheets,
  input, view models and requests.
- **Positive:** UI localization is discoverable and compiler-checked across
  packages without pulling UI concerns into `FitnessCore` or storage.
- **Positive:** Adding a language is a single catalog operation; picker options,
  locale selection and App Intent metadata require no parallel language switch.
- **Positive:** English remains stable for existing installations and is the
  fallback for incomplete German coverage.
- **Negative:** All visible text and locale-sensitive formatting must migrate
  atomically to avoid a mixed-language interface.
- **Neutral:** Language and accent use the same value-propagation principle but
  remain independently owned preferences. ADR-0019 remains authoritative for
  colors; its future-language constraint is implemented by this ADR.

## References

- [ADR-0019](0019-value-propagated-app-color-theme.md)
- `Packages/FitnessResources/Sources/FitnessResources/AppLanguage.swift`
- `Packages/FitnessResources/Plugins/GenerateLocalizationAPIPlugin/Plugin.swift`
- `Packages/FitnessResources/Sources/FitnessResources/Resources/Localizable.xcstrings`
- `FitnessApp/FitnessAppApp.swift`
