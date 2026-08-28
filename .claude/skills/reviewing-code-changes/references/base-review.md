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
8. Fix findings introduced by the current change before reporting PASS.
9. Treat this pass as the senior-quality review: inspect production readiness,
   not only whether the happy path works or tests are green.
10. Search changed code and immediate consumers for dead code: unused
    declarations, unreachable branches, obsolete compatibility paths, and
    helpers with no production-reachable caller.
11. Flag introduced code smells: duplicated decisions, mixed responsibilities,
    oversized bodies/functions, boolean-state combinations, and abstractions
    that obscure ownership.
12. Require unit coverage for feasible deterministic logic and state
    transitions. Reserve UI tests for integration, presentation, and wiring
    that a lower layer cannot prove.
13. Verify package direction and ownership. Views do not absorb navigation,
    persistence, or training logic; layers gain no parallel state owner or
    reverse dependency.

Do not run the test suite. Test selection and execution belong to the tester
phase; judging coverage here is item 12, not a reason to invoke `xcodebuild`.

Report findings as **Bug**, **Nit**, or **Pre-existing**, with file and line.
An empty review must state `No issues found`.
