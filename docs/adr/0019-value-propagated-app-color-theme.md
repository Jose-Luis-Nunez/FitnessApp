# 0019 — Value-propagated app color theme without identity reset

* Status: accepted
* Date: 2026-08-13
* Deciders: jose.nunez
* Supersedes: the runtime visual-subtree rebuild retained by ADR-0017
* Complements: ADR-0018

## Context

The persisted green/grey preference was read indirectly by computed global
`AppStyle.Color` properties. SwiftUI could not observe that process-global
`UserDefaults` lookup, so the app applied `.id(iconColorScheme)` to its visual
root to force a refresh. Changing the accent therefore replaced the complete
view subtree and reset feature-owned expansion state, navigation descendants,
view models and in-flight work.

Profile already used semantic roles, but owned a parallel Profile environment
key while default icons and other app features read persistence independently.
The result had multiple state boundaries for one preference and no compiler-
enforced way to find consumers that retained an old palette.

## Options

- **A — Keep the root identity reset:** minimal migration, but theme changes
  remain destructive to unrelated feature state.
- **B — Add an observable reference-type settings store:** observable, but
  creates shared mutable state and invites unrelated settings such as language
  to accumulate in an app-wide god object.
- **C — Inject one immutable color-theme value:** keep persistence at the
  composition root and let SwiftUI invalidate only environment consumers.

## Decision

Choose **Option C**.

`FitnessAppApp` is the sole `@AppStorage` owner for the accent preference and
preserves the existing key `defaultIconColorScheme` plus the raw values `green`
and `grey`. The user-facing enum is `AppAccentScheme`. The app root derives one
immutable `AppColorTheme` and injects it through `EnvironmentValues`.

`AppColorTheme` contains the selected `AccentPalette` and semantic feature
sub-palettes such as `ProfileColorTheme`. Views read the environment value;
non-View resolvers receive it explicitly. Dynamic colors are not exposed as
global `AppStyle.Color` properties, and components with themed defaults resolve
an optional caller override against the environment at render time. Stored
color presets that could capture an obsolete palette are removed.

`ProfileView` receives a binding to the root preference. No feature reads or
writes the accent storage key. Changing the binding updates environment
consumers without `.id`, explicit animation, feature-state lifting or
`SceneStorage` compensation.

ADR-0018 remains authoritative for the neutral `.primary` card surface. This
decision changes propagation and state ownership, not surface rendering, color
hexes, layout or semantic status colors.

### Future language preference

Language remains a separate dependency. A future localization migration should
place String Catalogs and typed `LocalizedStringResource` symbols in
`FitnessResources`, then inject `Locale` or a dedicated language preference at
the composition root. It must not be added to `AppColorTheme`, bundled into a
global `AppSettings` store, or refreshed through `.id`. The current static
`L10n` API and direct strings are outside this change.

## Consequences

- **Positive:** Accent changes preserve local view state, navigation, sheets,
  view models, requests and coordinator identity.
- **Positive:** Persistence ownership is singular and isolated previews/tests
  select a deterministic theme without process-global state.
- **Positive:** Removing legacy dynamic aliases makes incomplete migrations a
  compile-time error.
- **Positive:** Color and future language preferences can use the same
  propagation principle without sharing a domain model.
- **Negative:** Every dynamic accent and default-icon consumer must migrate in
  one repository-wide change.
- **Neutral:** `AccentPalette` remains the primitive ramp, `ProfileColorTheme`
  remains a semantic subset, and fixed `AppStyle.Color` tokens remain global.

## References

- [ADR-0017](0017-environment-injected-semantic-color-theme.md)
- [ADR-0018](0018-neutral-primary-card-surface.md)
- `Packages/FitnessUI/Sources/FitnessUI/AppAccentScheme.swift`
- `Packages/FitnessUI/Sources/FitnessUI/AppColorTheme.swift`
- `FitnessApp/FitnessAppApp.swift`
- `.claude/references/architecture-documentation.md`
