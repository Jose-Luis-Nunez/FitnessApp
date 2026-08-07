# 0017 — Environment-injected semantic color theme

* Status: accepted
* Date: 2026-08-07
* Deciders: jose.nunez

## Context

Profile UI previously referenced concrete global colors such as `greenLight`,
`gray`, and a translucent card fill at individual call sites. Aligning Profile
with the training idle-card palette therefore required editing unrelated feature
views, exposed inconsistent surface hierarchy, and made isolated previews and
snapshots depend on the process-wide `UserDefaults` palette selection.

The color system must keep raw palette values centralized, support the persisted
green and grey/orange schemes, update through SwiftUI state, and give feature
views semantic roles rather than concrete color names. Shared profile surfaces
must also remain persistence- and feature-state-independent.

## Options

- **A — Continue using concrete `AppStyle.Color` values:** minimal new API, but
  preserves call-site coupling and global palette resolution.
- **B — Add static semantic aliases only:** improves naming, but isolated views
  still read process-global state and repeated card/tile composition remains.
- **C — Inject semantic component tokens through the SwiftUI environment:** map
  the selected palette once, then render through shared profile components.

## Decision

Choose **Option C**.

`FitnessUI.ProfileColorTheme` maps `DefaultIconColorScheme.palette` into semantic
roles for primary text, secondary text, accent, filled accent, on-accent copy,
read-only surfaces, editable surfaces, strokes, and dividers. `FitnessAppApp`
owns the persisted scheme and injects the resolved value through SwiftUI's
environment. Tests and previews inject `.green` or `.grey` directly and never
mutate `UserDefaults` to select a visual theme.

`ProfileCardContainer`, `profileCardSurface`, and
`profileReadOnlyTileSurface` own reusable profile surface composition in
`FitnessUI`. Profile, Friends, and transit views consume theme roles and these
components; they do not contain palette literals or resolve persistence.
Training and Profile continue to derive accents from the same `AccentPalette`
and use the same idle-card surface. BMI, warning, error, and transit-status
colors remain separate semantic roles.

This ADR does not require an app-wide migration of every legacy accent consumer.
The existing visual-subtree rebuild remains for those consumers until they gain
their own semantic component themes; new Profile UI must use this boundary.

## Consequences

- **Positive:** Future Profile palette changes are localized to the theme or a
  shared component instead of feature call sites.
- **Positive:** Runtime switching is observable through SwiftUI environment
  propagation, and isolated rendering is deterministic.
- **Positive:** Component surfaces cannot drift independently across Profile,
  Friends, and transit screens.
- **Negative:** Existing Profile-family views require a one-time migration from
  concrete colors to semantic roles.
- **Neutral:** Raw color primitives and the persisted palette enum remain in
  `FitnessUI`; feature state and persistence ownership do not change.

## References

- `Packages/FitnessUI/Sources/FitnessUI/ProfileDesignSystem.swift`
- `Packages/FitnessUI/Sources/FitnessUI/AccentPalette.swift`
- `FitnessApp/FitnessAppApp.swift`
- `.claude/references/architecture-documentation.md`
