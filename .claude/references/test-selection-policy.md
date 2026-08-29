# Risk-Based Test Selection

Choose tests for the risk they remove, not because a production file or View
exists. Every new test and every affected legacy test passes this gate before
it is added, retained, or re-recorded.

## Domain Baseline

Run `bash .claude/hooks/lib/test-domain-risk.sh classify worktree` when choosing
or updating tests. The highest affected domain establishes the initial tier:

| Domain | Tier | Scope |
|---|---|---|
| Training and Exercise | **Blocker** | Training flow; exercise management; active, idle and inactive cards; set/card primitives; list and category views |
| Workouts | **High** | Workout creation, editing, ordering, import/export and workout UI |
| Analytics | **High** | Analytics capture, calculation, persistence and presentation |
| Profile | **Low** | Profile, Friends and profile-owned transit presentation |
| Feedback | **Low** | Feedback sheet, feedback presentation/state and feedback persistence |
| Unmapped | **Medium** | Evaluate using the Selection Gate below |

The domain tier is a baseline. Technical signals such as data loss, persistence,
concurrency, cross-package contracts, or a historically fragile path may raise
it; they never lower it. For mixed changes, the highest affected tier wins.

### Meaning of the tiers

- **Blocker:** Relevant automated evidence must pass before the change is
  considered complete. Protect deterministic behavior below UI and add a
  critical-path UI test when the changed user flow cannot be proven otherwise.
  A snapshot alone is insufficient for behavioral risk.
- **High:** Meaningful behavior changes require focused unit or integration
  coverage and an affected-package test run. Add UI coverage only for an
  important boundary that lower layers cannot prove.
- **Medium:** Use the Selection Gate without a domain-specific presumption.
- **Low:** Pure presentation, copy, or color work normally requires no new test.
  Add focused coverage when the change introduces real logic, data, or failure
  risk; do not preserve low-value snapshots mechanically.

## Selection Gate

Answer these questions in order:

1. **Behavior at risk:** What user-visible behavior, business rule, data
   contract, or reusable visual contract could regress?
2. **Impact:** Would failure cause data loss, an incorrect training result, a
   broken primary journey, or broad UI inconsistency? Rate high, medium, or low.
3. **Likelihood:** Is the behavior complex, frequently changed, shared, or
   historically fragile? Rate high, medium, or low.
4. **Detection advantage:** What is the lowest deterministic layer that catches
   the regression? Prefer unit over integration, and integration over UI.
5. **Maintenance cost:** Include fixture churn, runtime, flakiness, baseline
   review, and how often intentional changes will require updates.
6. **Decision:** Add, retain, replace, or remove the test. A test is justified
   only when its expected risk reduction clearly exceeds its maintenance cost.

## Test-Type Policy

| Test type | Use when | Avoid when |
|---|---|---|
| Unit | Deterministic rules, state transitions, formatting, resolvers, failure paths | The test only repeats implementation details |
| Integration | Persistence, dependency wiring, service contracts, or package boundaries are the risk | A focused unit test proves the same behavior |
| UI | A critical user journey or platform integration cannot be proven below the UI layer | The scenario is cosmetic, secondary, or already covered below the UI |
| Snapshot | A stable, reusable visual contract has meaningful geometry/style semantics and broad consumers | A feature screen is rarely changed, cosmetic drift has low impact, or every intentional redesign causes baseline churn |

Being a `public View` is not sufficient evidence for a snapshot. Prefer a
snapshot of a shared primitive or component over snapshots of every feature
composition that consumes it.

## Retention and Change Rules

- A useful test fails for a meaningful regression and stays stable for
  intentional changes outside its contract.
- When an intentional change affects a low-value legacy test, remove the test,
  its baselines, and dependencies used only by it instead of re-recording it.
- Re-record a snapshot only after its visual contract passes the Selection Gate.
- Do not add a high-level test merely to satisfy coverage counts or file-name
  conventions.
- In the final handoff, state which test layer was selected and why; if no new
  test is justified, state the risk-based reason.

## Package Scope

Selection starts from `package-dependents.sh scope`, not from the changed paths
alone. A changed `public`/`open` declaration pulls in the packages that consume
it; a private change stays in its own package. Without this a public signature
change selected only its own package while consumers in other packages went
untested with every gate green.
