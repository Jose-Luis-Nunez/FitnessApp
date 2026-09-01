# 0022 — Coaching-phase read follows the affordance's visibility

* Status: accepted
* Date: 2026-08-31
* Deciders: jose.nunez

## Context

ADR-0016 placed the exercise card's three reads at three gestures: existence on
appearance, the latest entry after Last run is tapped, and the complete history
after the coaching-tip button is tapped. That held while the coaching-tip button
was unconditionally visible.

It no longer is. A coaching tile describes a *weight increase*, so an exercise
that has only ever been trained at one weight has nothing to show. The button
must not be offered in that case — otherwise it opens onto an empty row, or,
as it did, silently swallows the tap. Deciding that requires knowing whether an
increase exists, and that answer is only derivable from the complete history:
the phase grouping compares the maximum weight of every training day.

So the read that ADR-0016 attached to the button's tap is now needed to decide
whether the button exists at all. The two cannot both be satisfied.

## Options

- **A — Keep the read on the tap, leave the button always visible:** preserves
  ADR-0016 verbatim and keeps the empty-tap defect, which is the product bug
  being fixed.
- **B — Add a dedicated availability query "has this exercise ever increased":**
  keeps the full read on the tap, but the question is not answerable by an
  identifier-only or single-entry fetch — it needs the same per-day scan. It
  would duplicate phase detection in `FitnessStorage` and add a fourth cache
  stage, for no reduction in work.
- **C — Move the full read to the gesture that reveals the button:** the
  coaching button exists only inside the expanded Last run row, which is itself
  an explicit user gesture.

## Decision

Choose **Option C**, superseding only the sentence in ADR-0016 that places the
full history read after the coaching-tip tap. Everything else in ADR-0016 stands:
the three cache stages, the exercise-scoped revisions, the absence of any parent
prefetch, and identifier-only existence checks on appearance.

`IdleActiveCardModelView` loads the complete history when the Last run row is
expanded, and renders the coaching-tip button only when that history yields at
least one phase. Tapping the button then performs no read — the history is
already cached under the same exercise. The phase state is cleared when the row
collapses and re-read when the card reappears with the row still open, so the
button's presence can never outlive the data it depends on.

The rule that produces the phases lives in `AnalyticsViewModel`, not in the view:
`weightPhases(from:limit:)` and `repsPhases(from:limit:)` pair each grouping with
its predecessor and keep only those that exceed it. That drops the opening phase,
which nothing preceded, and also every deload — a change of level in either
direction opens a grouping, but only a step up is progress. The view's visibility
condition is therefore the plain emptiness of the returned array.

## Consequences

- **Positive:** An affordance is offered only when it leads somewhere. The
  swallowed tap disappears rather than being handled.
- **Positive:** Total reads per full drill-down are unchanged — one complete
  history read, one gesture earlier.
- **Positive:** No new storage API, cache stage, or duplicated phase logic.
- **Negative:** Expanding Last run costs one complete history read even if the
  user never opens the coaching tiles. Scrolling and appearance are unaffected.
- **Negative:** The card holds phase state for as long as the Last run row is
  open, rather than only while the tiles are shown.
- **Neutral:** ADR-0016's principle — card reads follow explicit UI intent —
  is preserved; only which intent triggers this read changes.

## References

- ADR-0016 — Demand-loaded exercise-card analytics (partially superseded)
- `Packages/FitnessAnalytics/Sources/FitnessAnalytics/AnalyticsViewModel.swift`
- `Packages/FitnessAnalytics/Sources/FitnessAnalytics/AnalyticsViewModel+Reps.swift`
- `Packages/FitnessPersistenceUI/Sources/FitnessPersistenceUI/IdleActiveCardModelView.swift`
- `Packages/FitnessCore/Sources/FitnessCore/WeightPhase.swift`
