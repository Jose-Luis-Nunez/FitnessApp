# SwiftUI and Layout Review

Load when changed production files contain SwiftUI Views or AppStyle.

- Business decisions belong in state/use cases, not `body`.
- Reuse existing FitnessUI/FitnessPersistenceUI components before extracting a
  new abstraction.
- Use AppStyle tokens for shared visual values. A local one-off geometry
  constant may remain local when it is not a design-system value.
- Avoid screen/device-name checks. Layout from the actual container.
- Verify compact and large widths when horizontal content changed.
- Preserve minimum tap targets and accessibility identifiers.
- Custom interactive rows expose a useful VoiceOver label, value, traits, and
  actions. Identifiers alone are not accessibility coverage.
- Public shared Views need snapshot coverage. Existing snapshots must pass
  unchanged for claimed visual-preserving refactors.
- A changed visual baseline must be inspected; re-recording is not proof that
  the new rendering is correct.
- Snapshot inspection confirms referenced app artwork actually renders; an
  empty reserved image column is a failure, not an acceptable baseline.
