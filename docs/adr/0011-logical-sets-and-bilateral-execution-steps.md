# 0011 — Logical sets and bilateral execution steps

* Status: accepted
* Date: 2026-07-30
* Deciders: jose.nunez

## Context

Some exercises require the same movement once per side. A configured target of
three sets therefore means three logical sets but six individual executions:
Left 1, Right 1, Left 2, Right 2, Left 3, Right 3.

Treating those executions as six configured sets would make the exercise form,
idle card, progression rules, and analytics describe the workout incorrectly.
Treating historical standard results as implicit Left values would also invent
meaning that was never recorded.

The app has not been released to customers. Development installs may be reset,
and workout data can be restored through the version-1 import format. There is
therefore no deployed V6 store that warrants a V7 migration solely for this
feature.

## Options

- **A — Double `Exercise.sets`:** Store six sets for a three-set bilateral
  exercise and infer the side from array position.
- **B — Store a second Right-only result beside each existing set:** Interpret
  every existing set as Left and add separate Right properties.
- **C — Keep logical sets and flatten explicit execution steps:** Add an
  execution mode to `Exercise`; store optional side and logical-set metadata on
  every result; derive the session steps from the frozen exercise snapshot.
- **D — Introduce Schema V7 and migrate V6:** Snapshot the affected relationship
  clusters and add a lightweight V6→V7 stage.

## Decision

Choose **Option C**, with a pre-release schema choice from the constraint above.

`Exercise.sets` remains the logical set count. `Exercise.executionMode` is
either `standard` or `bilateral`, and `Exercise.trainingSteps` expands the
configuration deterministically. Standard mode yields one side-less step per
logical set. Bilateral mode yields Left then Right for every logical set.

`SetProgress.side` and `SetProgress.logicalSetIndex` identify individual
results. Both are optional so legacy JSON and mixed analytics remain valid and
continue through the flat standard presentation. New bilateral sessions always
write both values.

`ActiveSetViewModel` owns one state machine over the flattened steps; it does
not create independent Left and Right view models. The coordinator retains that
state when focus changes, so the step, side, timer, and completed results resume
together. The UI renders the same shared set-row implementation in two columns
only when the frozen exercise snapshot is bilateral.

Analytics stores the flat execution order and derives Left/Right groups by
`logicalSetIndex` only when the metadata forms complete, unambiguous pairs.
Deleting a displayed bilateral logical set removes both executions. Metrics
still inspect both results; total reps sum both sides while set labels use the
logical count and the `/ side` suffix. Weight phases group complete logical
pairs before filtering by phase weight and use the higher side weight for the
phase. This keeps an asymmetric pair (for example Left 20 kg and Right 22 kg)
intact instead of silently degrading it to one physical result.

Manual analytics entry uses one form-state owner for both standard and
bilateral input. Editing preserves result IDs, side metadata, and logical set
indices. The use case exposes explicit standard-set and bilateral-logical-set
deletion operations so invalid combinations cannot cross the boundary.

Quick Done is intentionally a one-tap operation that completes the entire
derived step sequence. There is no second row-by-row Quick Done state machine.
For weight progression, a bilateral result set must match the configured
Left/Right sequence exactly; extra, missing, duplicated, or misordered steps do
not qualify.

The current development `SchemaV6` is amended directly with optional
`ExerciseModel.executionModeRaw`, `SetProgressModel.sideRaw`, and
`SetProgressModel.logicalSetIndex`. No Schema V7 or V6→V7 migration is added.
This is a scoped pre-release exception to ADR-0005, not a general relaxation:
after the first customer release, persisted-model changes again require a new
schema version and migration coverage.

Workout export remains version 1 because the Codable additions are additive.
Old exercise JSON decodes as standard; old set progress decodes without side
metadata. Import, duplication, and friend envelopes preserve the new metadata.

## Consequences

- **Positive:** Configured set counts keep their user-facing meaning.
- **Positive:** Left and Right results remain independently editable and
  analyzable without duplicating the training state machine.
- **Positive:** Standard exercises and legacy analytics retain their prior
  behavior and presentation.
- **Positive:** Cancel, resume, Quick Done, Less/Done/More, and progression all
  operate on the same explicit step sequence.
- **Negative:** Callers that determine training completion must use
  `trainingSteps.count`, not `sets`.
- **Negative:** Analytics must validate pair completeness before grouping and
  retain a flat fallback for legacy or mixed data.
- **Negative:** Existing development installations must be deleted/reinstalled
  after the V6 model shape changes.
- **Neutral:** No start-side picker is introduced; Left always precedes Right.

## References

- ADR-0003 — Coordinator session-state contract
- ADR-0005 — SwiftData Schema Migration Strategy
- `Packages/FitnessCore/Sources/FitnessCore/Exercise.swift`
- `Packages/FitnessCore/Sources/FitnessCore/SetProgress.swift`
- `Packages/FitnessTraining/Sources/FitnessTraining/ActiveSetViewModel.swift`
- `Packages/FitnessAnalytics/Sources/FitnessAnalytics/BilateralSetGrouping.swift`
- `Packages/FitnessStorage/Sources/FitnessStorage/Schema/SchemaV6.swift`
