# 0012 — Risk-based, content-bound agent validation

* Status: accepted
* Date: 2026-07-31
* Deciders: Jose Nunez

## Context

The previous workflow applied the same 763-line review process to nearly every
Swift change, passed a large architecture reference to reviewers, repeated
successful final tests in a tester subagent, and required an infrastructure
verifier after ordinary product-documentation updates.

Validation stamps were time-based and keyed primarily by changed file names.
They could expire without content changes while failing to distinguish a later
edit to the same file.

## Options

- **A — Keep uniform validation:** strongest ceremony, highest prompt and test
  cost, weak content identity.
- **B — Remove independent validation:** lowest cost, unacceptable regression
  risk for persistence/state/navigation work.
- **C — Risk-routed validation with content manifests:** retain independent
  review for meaningful changes, use lightweight validation for presentation
  changes, and bind all evidence to exact contents.

## Decision

Choose **C**.

- Classify changes as green, yellow, or red using conservative paths and diff
  signals.
- Green changes use a main-agent review and one relevant final test.
- Yellow/red changes use fresh reviewer and tester agents without conversation
  history.
- A tester verifies a matching final result instead of repeating it.
- Code/test manifests hash relevant file contents. Stamps do not expire while
  those contents remain unchanged.
- Product references do not trigger agent-infrastructure verification.
- `.claude` is canonical; Codex adapters are generated and drift-checked.
- Test creation and retention use the same risk principle: select the lowest
  deterministic layer whose regression detection justifies its maintenance
  cost. Public visibility or a matching production filename never mandates a
  test by itself.
- Test selection starts with a product-domain baseline: Training/Exercise is
  blocker; Workouts and Analytics are high; Profile and Feedback are low;
  unmapped areas default to medium. Mixed changes take the highest tier and
  technical risk can only raise it.
- Snapshot tests are reserved for stable reusable visual contracts. Low-value
  feature snapshots are removed with their baselines and snapshot-only
  dependencies instead of being mechanically re-recorded.
- The development hook surfaces a deduplicated test-selection hint whenever
  tests change or new ViewModel/Service logic needs a coverage decision.

## Consequences

**Positive**

- Small and medium tasks consume substantially less prompt context.
- Final tests run once per exact code state.
- A same-path edit invalidates evidence immediately.
- Reviewer independence improves because implementation conversation is absent.
- Runtime-adapter drift becomes deterministic.
- Test suites accumulate less low-signal snapshot and UI-test maintenance.
- Agents must make the test-layer decision explicitly before writing or
  updating tests.

**Negative**

- Risk classification is heuristic and requires fixture tests.
- Local validation state uses manifests in addition to human-readable stamps.
- Conservative classification may occasionally escalate a low-risk change.

**Neutral**

- Pre-commit remains versioned through ADR-0006.
- ADR, SwiftData, UI-state, snapshot, and independent review protections remain
  for yellow/red changes.

## References

- ADR-0006 — Versioned Git hooks
- `.claude/references/agent-system-overview.md`
- `.claude/hooks/lib/change-risk.sh`
- `.claude/hooks/lib/validation-evidence.sh`
- `.claude/hooks/checks/test-selection.sh`
- `.claude/hooks/lib/test-domain-risk.sh`
- `.claude/references/test-selection-policy.md`
