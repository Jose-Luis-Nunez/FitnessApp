# 0018 — Neutral primary card surface

* Status: accepted
* Date: 2026-08-12
* Deciders: jose.nunez
* Supersedes: ADR-0017

## Context

ADR-0017 established an environment-injected semantic color theme for Profile,
but described Profile as consuming the Training-specific idle-card surface.
That coupled a reusable visual primitive to a feature state and made
`CardBackground(style: .idle)` misleading outside Training.

Profile also needs a neutral selected-state treatment for its palette control.
Selection must remain visible without making the grey option orange or otherwise
encoding the selected palette in the control chrome.

## Options

- **A — Keep `CardSurfaceStyle.idle`:** no migration, but feature-state language
  remains embedded in a reusable visual primitive.
- **B — Duplicate a Profile-specific surface:** removes the naming leak, but
  creates two implementations that can drift despite an identical visual contract.
- **C — Introduce a neutral primary surface:** keep one visual primitive while
  Training maps its idle semantics through `CardTheme` and Profile consumes the
  neutral primitive directly.

## Decision

Choose **Option C**.

`FitnessUI.CardSurfaceStyle.primary` owns the shared gradient, glow and contour.
Training-specific presets such as `CardTheme.idle` and
`CardTheme.inactiveOnIdle` retain their domain names and map internally to
`.primary`. Profile consumes `.primary` through `ProfileCardContainer`, so it
does not depend on a Training state.

`ProfileColorTheme` remains the semantic environment boundary introduced by
ADR-0017 and additionally owns neutral `selectionBackground` and
`selectionStroke` roles. Both palette options use those roles; selected state is
communicated through contrast and outline rather than the palette accent.

The migration is atomic: `CardSurfaceStyle.idle` is removed rather than retained
as a deprecated alias. Existing `idleCard…` color tokens and Training-facing
`CardTheme` names remain unchanged because they still describe Training domain
semantics.

## Consequences

- **Positive:** Shared rendering terminology is feature-neutral.
- **Positive:** Training and Profile keep one pixel-identical surface implementation.
- **Positive:** Profile palette selection remains visually neutral and accessible
  in both supported palettes.
- **Negative:** Renaming the enum case requires every repository consumer and its
  reusable snapshot contract to migrate atomically.
- **Neutral:** Inner tile/input surfaces and existing raw `idleCard…` tokens are
  outside this decision.

## References

- [ADR-0017](0017-environment-injected-semantic-color-theme.md)
- `Packages/FitnessUI/Sources/FitnessUI/CardBackground.swift`
- `Packages/FitnessUI/Sources/FitnessUI/CardTheme.swift`
- `Packages/FitnessUI/Sources/FitnessUI/ProfileDesignSystem.swift`
