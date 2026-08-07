# Test Change Review

Load when tests, test support, fixtures, snapshots, or UI-test infrastructure
changed.

- Apply `.claude/references/test-selection-policy.md` before reviewing test
  implementation details. New and affected legacy tests must justify their
  layer and maintenance cost; remove low-value tests and test-only dependencies
  instead of preserving them mechanically.
- Run `bash .claude/hooks/lib/test-domain-risk.sh classify worktree`. Treat
  Training/Exercise as blocker, Workouts/Analytics as high, and
  Profile/Feedback as low; technical signals may raise but never lower the tier.
- Tests exercise a production-reachable path, not an otherwise unused API.
- Mocks reproduce production callback side effects and preserve scope/identity
  inputs such as workout or exercise IDs; tests do not pre-prime the state that
  the action is supposed to produce.
- Prefer Swift Testing and shared FitnessTestSupport utilities.
- Cover deterministic branches, state transitions, resolver decisions, and
  failure/cancel behavior with unit tests whenever their production boundary is
  injectable. Do not rely on UI tests alone for behavior that a focused unit
  test can prove faster and more precisely.
- Time-dependent code uses an injected clock rather than real sleeps.
- Assertions include the important negative condition, identity, ordering, or
  metadata—not only a count.
- Snapshots protect a stable reusable visual contract, not merely a `public`
  View or rarely changed feature composition. Retained snapshot fixtures are
  deterministic and checked in. Dates inject calendar, locale, and timezone;
  app-owned images use a test-visible provider and are confirmed visually in
  the recorded baseline.
- UI tests use production accessibility identifiers, the shared DSL, and the
  `FitnessApp UITests` scheme.
