# Feedback entry-point artwork

Unscaled masters for the feedback entry-point icon states, kept outside
`FitnessApp/Assets.xcassets` so they are versioned but never shipped in the app
bundle.

These are pixel-identical re-encodes of the delivered files, not the delivered
bytes: they were written through Pillow with `optimize=True`, which strips
ancillary PNG chunks and recompresses the image data. Every RGBA pixel and the
IHDR geometry match the originals exactly — verified by full-buffer comparison —
so they are a faithful archive, but a byte-level "is this what the designer
sent?" check will not match.

They are **not** interchangeable with the catalog files: each master fills its
canvas differently — the ECG trace spans
0.620, 0.847 and 0.833 of the canvas width respectively, and `feedback_entry_done`
was delivered on a 3:2 canvas rather than a square one. Rendered through the
button's single `.fit` path that produced three visibly different sizes, with
`done` also a third shorter than its siblings.

The catalog derivatives in `feedback_entry_{2,draft,done}.imageset` are therefore
normalised, not merely resized. Two quantities measured from `feedback_entry_2`
are held constant across all three:

| quantity | value |
|---|---|
| ECG trace width / canvas width | 0.6215 |
| trace baseline y / canvas height | 0.51 |

Each master is cropped to its content, scaled to that trace width, and placed on
a square transparent canvas with the baseline at that height, at 96 / 192 / 288 px
for `@1x` / `@2x` / `@3x`. Badges (checkmark, pencil) then sit above-right of an
identically sized trace in every state.

Apparent size in the app is one constant, `feedbackIconZoom` in
`BottomActionBarView`, and `BottomActionBarViewSnapshotTests.feedbackIcon`
renders all three states so a size or clipping difference is visible rather than
inferred. Regenerate the derivatives from these masters if that constant or the
trace fraction changes.
