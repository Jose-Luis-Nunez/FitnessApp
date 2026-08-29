# H: Snapshot Tests

Snapshot tests guard selected reusable visual contracts in `FitnessUI` and
`FitnessPersistenceUI`. Before adding, retaining, or re-recording one, apply
`.claude/references/test-selection-policy.md`. They live in:

- `Packages/FitnessUI/Tests/FitnessUITests/SnapshotTests.swift`
- `Packages/FitnessPersistenceUI/Tests/FitnessPersistenceUITests/IdleCardSnapshotTests.swift`

Recorded baselines are PNGs under each package's `Tests/<Package>Tests/__Snapshots__/<TestFileName>/`.

#### H.1 — Conventions

```swift
@Suite("<ViewName> — Snapshots", .tags(.snapshot))
@MainActor
struct <ViewName>SnapshotTests {

    @Test func <variant>() {
        let view = <ViewName>(/* minimal valid init */)
        assertSnapshot(of: view, named: "<file-friendly-variant>", size: CGSize(width: 100, height: 100))
    }
}
```

- **Suite name pattern:** `"<ViewName> — Snapshots"` (em-dash separator). Tag every snapshot suite with `.tags(.snapshot)` so they can be filtered/skipped as a group.
- **`@MainActor` on the suite**, not the test — Views must be constructed on the main actor.
- **`named:` argument** is the file-name fragment for the PNG. Use kebab-case to match the convention seen in `__Snapshots__/SnapshotTests/*.png` (e.g. `idle-styled-reset`, `with-weight`, `expanded`).
- **`size:`** — 100×100 for small leaf components (icons, buttons, chips), `CGSize(width: 360, height: <natural>)` for cards or full-width components. Avoid arbitrary frames that hide overflow.
- One `@Test` per **meaningful** visual variant, not per prop combination. Three to five variants (default, edge case, interaction state) is healthy; ten variants of the same View is a smell.

#### H.2 — Where snapshot tests are required vs optional

No View requires a snapshot solely because it is `public` or lives in a shared
package. Select coverage by risk:

| View kind | Snapshot decision |
|---|---|
| Stable shared primitive/component with broad consumers and meaningful visual semantics | Usually justified when a pixel-level regression would affect several screens. |
| Shared stateful component with distinct meaningful visual states | Consider a small set of representative variants after lower-level behavior tests. |
| Feature screen/composition that changes rarely | Usually no snapshot; test risky logic below the UI and inspect intentional design changes directly. |
| Thin wrapper around a covered component | No snapshot. |
| `internal` / `fileprivate` View | Usually covered through the selected public component, if any. |
| Pure non-View type | No snapshot; use a unit test only when behavior risk warrants it. |

The reviewer must name the visual contract, regression impact, likelihood, and
maintenance cost. If that case is weak, recommend no snapshot or removal of the
legacy snapshot.

#### H.3 — When to re-record a retained baseline

Snapshot tests are not a development test. Ten edits in a row do not need ten
snapshot runs, and re-running them after each edit only reproduces the same
known failure at the price of a serialized simulator phase. Keep working, then
re-record once at the start of the commit flow -- `/validate` step 3 -- so the
candidate settles before any stamp binds to it.


First re-run the Selection Gate. Re-record only when the snapshot remains worth
maintaining and the visual change is **intentional**:

- new color/gradient/font token
- changed layout proportions (sizes, paddings, offsets)
- added/removed visual layer (halo, ring, edge indicator, gradient)
- corner radius / opacity / shadow change

Do **not** re-record to "make a failing test pass" without auditing the diff. A snapshot failure on a refactor that *should* be visually equivalent is a real regression — investigate before re-recording.

Re-record flow:

**`RECORD_SNAPSHOTS=1` does not work through the script.** The helper reads it
from the test process environment, and that environment is defined by
`TestPlans/FitnessSnapshots.xctestplan`, which does not pass it through.
Measured 2026-08-29: a perturbed padding failed the same two snapshots with and
without the variable, and no baseline was rewritten. Passing it as
`TEST_RUNNER_RECORD_SNAPSHOTS` or as a plain build setting was tried and did not
work either. The env var still applies when running the suite from Xcode
directly, where the scheme supplies the environment.

The working flow through the script is to flip the flag in the code:

```bash
# 1. Set `record: true` on the failing assertSnapshot(...) call.
# 2. Run the suite; the helper writes straight into the source __Snapshots__.
scripts/test-affected-packages.sh --snapshots FitnessUI
# 3. Revert the `record:` change, then inspect every changed image.
git diff -- Packages/FitnessUI/Tests/FitnessUITests/__Snapshots__/
```

Verify the revert by comparing the file hash, not by trusting the edit. Git
actions remain subject to the authority boundary in `AGENTS.md`.

#### H.4 — Smells

| Smell | Why it hurts | Fix |
|---|---|---|
| Snapshot test exists but no baseline PNG | CI has no stable reference image. | Run once with `RECORD_SNAPSHOTS=1`, inspect the PNG, and retain it in the working-tree candidate. |
| `@Test` per prop combination (12+ tests for one View) | Every visual tweak forces re-recording dozens of baselines. | Collapse to 3–5 meaningful variants; let unit tests cover prop logic. |
| Feature-page snapshot retained only because it already exists | Intentional UI work creates recurring baseline churn without protecting a critical contract. | Apply the Selection Gate; remove the test, baselines, and snapshot-only dependency when value is low. |
| Re-recorded baseline in a "no-visual-change" refactor PR | The refactor was not pixel-equivalent — a real regression hidden as a re-record. | Stop, diff the old/new PNG visually (`git diff -- '**/*.png'` or open both), explain in PR description, or revert. |
| Snapshot of a View that owns dynamic data (date, random, animated) | Flaky baseline. | Inject the dynamic input as a parameter; pass a fixed value in the snapshot. |
| Missing `@MainActor` → compiler / runtime error | n/a | Add `@MainActor` on the `struct`. |
