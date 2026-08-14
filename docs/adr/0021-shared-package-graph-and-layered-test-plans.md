# 0021 — Shared package graph and layered test plans

* Status: accepted
* Date: 2026-08-14
* Deciders: FitnessApp maintainers

## Context

The feature modules were independent local Swift packages. That preserved good
module boundaries, but a complete validation launched twelve unrelated
`xcodebuild` actions. Each action repeated package resolution, build planning,
linking, test-host preparation and simulator work even though the tests
themselves were short. Concurrent package processes also could not coordinate
their compiler or simulator load globally.

Several test targets mixed pure logic, SwiftData integration contracts and
image snapshots. This forced simulator execution and SnapshotTesting into fast
developer loops. Mockable was attached to `FitnessCore`, so its macro graph was
present for every downstream debug build despite only a few storage tests using
generated mocks.

## Options

- Keep independent package manifests and tune outer process parallelism.
- Merge feature source into fewer modules.
- Preserve feature modules while centralizing package resolution and separating
  tests by execution requirements.

## Decision

`Packages/Package.swift` is the single SwiftPM manifest for all existing
feature modules. Module names, source ownership and dependency direction remain
unchanged; only dependency resolution and build planning are centralized. The
app project and `FitnessModules.xcworkspace` consume this graph.

Tests are split into four shared Xcode plans:

- `FitnessFast`: native macOS tests with no simulator or snapshot dependency,
  including portable in-memory SwiftData service tests;
- `FitnessIntegration`: schema migrations, bootstrap recovery and
  UIKit/platform contracts on the pinned iOS simulator;
- `FitnessSnapshots`: image snapshots on the pinned iOS simulator;
- `FitnessPreMerge`: the complete pinned-iOS compatibility set.

Snapshot source files live in dedicated test targets. Swift Testing remains
parallel by default; `.serialized` is limited to stateful migration and snapshot
suites. Xcode owns build/test-worker coordination inside each phase. The runner
must not create competing package-level `xcodebuild` processes.

Native test bundles may use parallel workers. Simulator integration and
snapshot phases run without parallel test clones: measurements on the pinned
runtime show that clone boot and test-host deployment cost more than the small
amount of test work. Build parallelism remains enabled for those phases.

Mockable is removed from `FitnessCore`. Shared handwritten fakes and explicit
call records in `FitnessTestSupport` replace the small generated-mock surface.

## Consequences

- Complete validation resolves external packages and plans shared targets once
  per phase instead of once per module.
- Fast tests can run without booting an iOS simulator; UIKit-dependent modules,
  SwiftData migrations and snapshots retain their correct platform coverage.
- Existing feature boundaries and imports remain intact. This is build
  consolidation, not a monolithic source-module refactor.
- A new module or test layer must be registered in the root manifest and the
  relevant test plan. Leaf `Package.swift` files are not reintroduced.
- Snapshot baselines remain tied to the pinned Xcode/runtime and do not run in
  the default native fast loop.
- Xcode beta diagnostics and compiler concurrency are measured with the runner's
  `--diagnose` mode before changing job limits.

## References

- [Apple: Organizing tests to improve feedback](https://developer.apple.com/documentation/xcode/organizing-tests-to-improve-feedback)
- [Apple: Swift Testing parallelization](https://developer.apple.com/documentation/testing/parallelization)
- [Apple: Improving incremental build speed](https://developer.apple.com/documentation/xcode/improving-the-speed-of-incremental-builds)
