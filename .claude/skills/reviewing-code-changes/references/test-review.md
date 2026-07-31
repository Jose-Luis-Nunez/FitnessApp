# Test Change Review

Load when tests, test support, fixtures, snapshots, or UI-test infrastructure
changed.

- Tests exercise a production-reachable path, not an otherwise unused API.
- Mocks reproduce production callback side effects; tests do not pre-prime the
  state that the action is supposed to produce.
- Prefer Swift Testing and shared FitnessTestSupport utilities.
- Time-dependent code uses an injected clock rather than real sleeps.
- Assertions include the important negative condition, identity, ordering, or
  metadata—not only a count.
- Snapshot fixtures are deterministic and checked in.
- UI tests use production accessibility identifiers, the shared DSL, and the
  `FitnessApp UITests` scheme.
