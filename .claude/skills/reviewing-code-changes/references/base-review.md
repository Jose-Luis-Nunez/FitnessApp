# Base Review

Load this checklist for every yellow or red change. Green changes use it as a
short self-review and do not spawn a reviewer.

1. Inspect only the changed code and immediate consumers.
2. Search removed or renamed symbols project-wide.
3. Check errors are surfaced rather than swallowed with `try?`.
4. Check new dependencies are explicit and testable.
5. Check mutable shared state has clear actor/main-actor isolation.
6. Check public API changes update every caller and test double.
7. Search changed production code for `print(`, stale TODO/FIXME markers, and
   commented-out implementations.
8. Run or verify the smallest complete test set for the affected behavior.
9. Fix findings introduced by the current change before reporting PASS.

Report findings as **Bug**, **Nit**, or **Pre-existing**, with file and line.
An empty review must state `No issues found`.
