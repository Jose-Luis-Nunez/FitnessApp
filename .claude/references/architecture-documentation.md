# FitnessApp Architecture

## Reading Guide

This file is a lookup reference for the current architecture. Locate the relevant
heading with `rg -n '^## |^### '` and read only the section selected by
`.claude/skills/reviewing-code-changes/references/architecture-routing.md`.

Document stable ownership, package boundaries, data flow, navigation, persistence
and public component contracts here. Implementation details such as token values,
view geometry, private methods, test inventories and rollout history belong in
source code, tests, ADRs or Git history.

## Architectural Decisions (ADRs)

Project-wide decisions live in [`docs/adr/`](../../docs/adr/README.md). Accepted
ADRs are immutable; a conflicting decision requires a new ADR that supersedes the
old one.

| ID | Decision |
|---|---|
| [0001](../../docs/adr/0001-model-as-ui-source-of-truth.md) | SwiftData models are the UI source of truth. |
| [0002](../../docs/adr/0002-persistence-ui-package.md) | `FitnessPersistenceUI` owns the primary SwiftData-to-SwiftUI integration boundary. |
| [0003](../../docs/adr/0003-coordinator-session-contract.md) | Training session state is owned by the coordinator. |
| [0005](../../docs/adr/0005-schema-migration-strategy.md) | Released SwiftData changes use versioned schemas and migrations. |
| [0006](../../docs/adr/0006-versioned-git-hooks.md) | Repository hooks are versioned and installed from the repository. |
| [0007](../../docs/adr/0007-remove-session-training-cache.md) | Persisted exercise state replaces the former session training cache. |
| [0008](../../docs/adr/0008-friends-comparison-isolated-blob-storage.md) | Imported friend workouts remain isolated as versioned blobs. |
| [0009](../../docs/adr/0009-targeted-exercise-update.md) | Single-exercise mutations use targeted persistence updates. |
| [0010](../../docs/adr/0010-workout-exercise-order-learning.md) | Exercise order is learned per workout across completed cycles. |
| [0011](../../docs/adr/0011-logical-sets-and-bilateral-execution-steps.md) | Logical sets and bilateral execution steps are distinct concepts. |
| [0012](../../docs/adr/0012-risk-based-agent-validation.md) | Agent validation is risk-based and bound to exact content. |
| [0013](../../docs/adr/0013-workout-analytics-batch-append.md) | Workout-wide analytics entries are appended atomically as a batch. |
| [0014](../../docs/adr/0014-training-session-sheet-presentation.md) | Training is an app-level presentation above its parent navigation flow. |
| [0015](../../docs/adr/0015-batched-analytics-snapshots.md) | Workout-wide analytics screens consume batched snapshots. |
| [0016](../../docs/adr/0016-demand-loaded-card-analytics.md) | Exercise cards load analytics progressively according to user intent. |
| [0017](../../docs/adr/0017-environment-injected-semantic-color-theme.md) | Superseded by ADR-0018; introduced the environment-injected Profile color theme. |
| [0018](../../docs/adr/0018-neutral-primary-card-surface.md) | Training semantics and Profile consume one feature-neutral primary card surface. |
| [0019](../../docs/adr/0019-value-propagated-app-color-theme.md) | One root-owned, value-propagated app color theme updates consumers without replacing view identity. |
| [0020](../../docs/adr/0020-app-language-localization-boundary.md) | Catalog-derived localization and one root locale preserve state across app-language changes. |
| [0021](../../docs/adr/0021-shared-package-graph-and-layered-test-plans.md) | One SwiftPM graph preserves module boundaries while native, integration and snapshot plans separate execution cost. |

## Feature Map

The app target composes package entry points, owns the root router and hosts the
bottom navigation. Product logic lives in Swift packages:

| Package | Responsibility |
|---|---|
| `FitnessCore` | Sendable domain values, storage protocols, identifiers and pure domain rules. It has no SwiftData or feature-UI ownership. |
| `FitnessStorage` | SwiftData models, schema migrations, storage services and persistence-oriented use cases. |
| `FitnessUI` | AppStyle, reusable visual primitives, shared card/sheet chrome and accessibility contracts. |
| `FitnessPersistenceUI` | SwiftUI components whose live state is backed directly by permitted SwiftData models and queries. |
| `FitnessExercise` | Workout home, category/list flows, exercise forms and navigation destinations. It hosts the approved workout-scoped query boundaries used by persistence-backed cards. |
| `FitnessTraining` | Training coordinator, active-set state, timer, feedback flow and the app-presented training sheet content. |
| `FitnessAnalytics` | Exercise analytics, workout-wide analytics, entry forms and analytics view models. |
| `FitnessSchedule` | Calendar, streak and day-detail projections built from workout analytics. |
| `FitnessWorkouts` | Workout CRUD UI, import/export, workout sharing and workout-scoped analytics entry. |
| `FitnessProfile` | Profile and body metrics plus BMI, Tram and S-Bahn integrations. |
| `FitnessFriends` | Friend import and workout comparison while keeping imported data isolated from the user's workout store. |
| `FitnessResources` | App language, the English-source String Catalog, typed localization resources and package-owned assets shared by package UI. |
| `FitnessTestSupport` | Stateful fakes, fixtures and asynchronous test helpers shared by package tests. It is not production architecture. |

All modules are declared by the single `Packages/Package.swift` manifest and
consumed by both the app project and the shared test workspace. This centralizes
dependency resolution and build planning without changing module ownership.
`FitnessFast` runs eligible test targets natively on macOS, including portable
in-memory SwiftData service tests. Schema migrations, UIKit integration targets
and snapshot targets remain isolated on the pinned iOS simulator.
`FitnessPreMerge` is the umbrella compatibility plan. ADR-0021 records the graph
and test-layer boundary.

### Main feature flows

- Workout and exercise lists render from workout-scoped SwiftData queries. Forms
  and business operations write through services or use cases; views do not mutate
  persisted models as an alternative write path.
- Starting training presents `TrainingSheetView` above the current Home or Category
  stack. The router owns presentation, while `TrainingCoordinator` owns the session.
- Exercise cards use demand-loaded analytics: availability for action visibility,
  the latest entry for an opened last-run section, and full history only for the
  coaching/phase drill-down. Parent lists do not prefetch full histories.
- `TotalAnalyticsView` and `ScheduleView` use a workout-wide
  `WorkoutAnalyticsSnapshot` so their rendered state is materialized before SwiftUI
  body evaluation.
- Profile transit cards restore route-scoped persisted results. S-Bahn network
  loads occur only after Refresh or a direction change; opening the card or returning
  to the foreground does not trigger a request.

## Domain Models

Domain types live in `FitnessCore` unless a type is strictly feature-local.
SwiftData models in `FitnessStorage` map persistence to these values and are not a
second domain model.

| Type | Architectural meaning |
|---|---|
| `Workout` / `WorkoutType` | A workout and its user-selected classification. Workout identity scopes exercises, learned order and analytics aggregation. |
| `Exercise` | Training configuration and current progress for one workout exercise. Identity is stable across UI projections and targeted writes. |
| `TrainingStep` | One executable step derived from an exercise's logical sets; bilateral exercises produce side-specific steps. |
| `AnalyticsEntry` / `SetProgress` | A dated exercise result and its physical execution results. Side and logical-set metadata preserve bilateral meaning without nesting persistence records. |
| `WorkoutAnalyticsSnapshot` | Sendable workout-wide read model containing exercises, deterministic flat entries and entries grouped by exercise ID. |
| `WeightPhase` | A derived analytics interval used for coaching and progress presentation. |
| `SeatSettings` | Optional equipment configuration associated with an exercise. |
| `ExerciseFeedback`, `Symptom`, `BodyRegion` | Per-training-session subjective feedback and its typed classifications. |
| `WorkoutShareEnvelope` | Versioned import/export boundary containing a workout, exercises and analytics. Imported identities are regenerated. |
| `Friend` and comparison values | Metadata and pure comparison projections for imported friend workout envelopes. |
| `MuscleCategoryGroup` | Stable category identity shared by exercise, training and navigation features. |

## Services

Factory containers register production implementations and define their lifetimes.
View models receive protocols or use cases through constructor injection, with
container resolution only as the composition default. Services own I/O; views do
not call storage or networking directly.

### Persistence services

| Service | Lifetime | Responsibility |
|---|---|---|
| `ModelContainerBootstrap` / shared `ModelContainer` | singleton | Opens the versioned SwiftData store, adopts supported legacy stores, restores or quarantines recoverable files, runs legacy import before storage services can seed defaults, and retains the container used by UI queries. |
| `WorkoutStorageService` | singleton | Workout CRUD, current/default workout selection and workout-scoped imports. |
| `ExerciseStorageService` | singleton | Workout/category reads, targeted exercise updates, bulk operations and workout-wide counts. Single-exercise mutations follow ADR-0009. |
| `ExerciseManagementService` | singleton | Exercise business operations composed over exercise, analytics and workout storage. |
| `WorkoutExerciseOrderStorageService` | singleton | Records workout-scoped starts, finalizes cycles and promotes an order only after repeated matching observations. |
| `AnalyticsStorageService` | singleton | Separates history availability, latest-entry, complete-history and chunked workout batch reads. Workout batch appends commit atomically. |
| `TotalAnalyticsStorageService` | singleton | Builds a workout-scoped `WorkoutAnalyticsSnapshot` from one exercise read plus bounded analytics batches. |
| `FeedbackStorageService` | singleton | Stores feedback per completed session and updates an existing record for the same session. |
| `FriendStorageService` | singleton | Stores imported friend envelopes independently from live workout models. |

Analytics read intents stay separate because they have different costs:

- Card visibility checks fetch only whether an entry exists.
- Opening a last-run section fetches at most the newest entry.
- Coaching and exercise analytics request one exercise's complete history.
- Total analytics and schedule use workout-wide batched snapshots.

Successful analytics writes invalidate only the affected exercise's cached stages.
Failed reads are not converted into cacheable empty results, so the same user intent
can retry without losing already visible data.

### Feature and integration services

| Service | Owner | Responsibility |
|---|---|---|
| `TrainingCoordinatorCache` | `FitnessTraining` | Provides one coordinator per muscle category and connects new-session events to learned exercise order. |
| `TimerService` | `FitnessTraining` | Rest timer over an injectable clock boundary. |
| `ExerciseFeedbackDraftStore` | `TrainingCoordinator` | Keeps the current exercise's unsaved feedback in memory; drafts are discarded with the owning session/exercise lifecycle. |
| `WorkoutImportCoordinator` / `FriendImportCoordinator` | `FitnessWorkouts` / `FitnessFriends` | Bridge app-level incoming files to their feature import flows, including cold launch before the screen mounts. The Add Friend form reuses its coordinator for an in-form system document picker before saving the named friend. |
| `BMIService` | `FitnessProfile` | Fetches remote BMI classification and provides a deterministic local calculation fallback. |
| `BVGTramService` / `TramDeparturesCache` | `FitnessProfile` | Loads live Tram departures and persists the latest route-scoped successful result. |
| `BVGHTTPTransport` | `FitnessProfile` | Shared cancellation-preserving HTTP boundary for Tram and S-Bahn with bounded transient retries, jitter, `Retry-After` support and status-code preservation. |
| `BVGTransitClient` | `FitnessProfile` | Builds documented BVG route/product queries and maps responses into transit domain values. |
| `BVGSBahnService` | `FitnessProfile` | Orchestrates configured-route classification, bridge resolution and direction-filtered fallback. It limits each visible load to the requested candidates and reuses successful stopover details through a bounded, short-lived in-memory cache. |
| `SBahnStopoverCache` | `FitnessProfile` | Keeps successful trip-stopover details in a capacity-bounded in-memory TTL cache; failed lookups remain retryable. |
| `SBahnClassifier` / `SBahnBridgeResolver` | `FitnessProfile` | Pure, direction-neutral S-Bahn routing rules with no I/O or cache ownership. |
| `SBahnRouteConfiguration` | `FitnessProfile` | Immutable route-specific vocabulary, stops, travel assumptions and bridge window. |
| `SBahnDeparturesCache` | `FitnessProfile` | Persists the latest successful result per direction. A direction change displays that result immediately and then performs one explicit refresh. |

### SwiftData Schema Versioning

The current store is `SchemaV6`, migrated by `AppMigrationPlan`:

| Version | Structural change |
|---|---|
| V1 → V2 | Adds the workout foreign key used by scoped exercise queries. |
| V2 → V3 | Adds isolated friend storage. |
| V3 → V4 | Adds exercise activation state. |
| V4 → V5 | Adds workout type. |
| V5 → V6 | Adds workout-scoped learned exercise order. |

Additive fields that must survive lightweight migration remain optional when the
old rows cannot satisfy a non-optional column before migration code runs. Their
domain mapping supplies the current default. Bilateral fields follow the scoped
pre-release policy recorded in ADR-0011.

`ExerciseModel`, `WorkoutModel` and related persistence types are exposed through
`@_spi(PersistenceUI)`. The allowed consumers are `FitnessPersistenceUI`, storage
tests, and the explicit query-host views in `FitnessExercise`. Other feature
packages use public domain and service APIs. Extending this SPI boundary requires
architecture review under ADR-0002.

## Use Cases

Use cases coordinate multi-step business operations and provide one semantic
entry point to view models or coordinators. Simple storage reads do not require a
wrapper merely to satisfy naming consistency.

| Area | Use-case boundary |
|---|---|
| Workouts | Delete chooses a valid current-workout fallback; duplicate copies all workout exercises; import regenerates identities and never overwrites an existing workout; export creates the versioned share envelope. |
| Analytics | Save/replace and logical-set deletion preserve bilateral metadata; workout-wide entry appends use the atomic batch boundary. |
| Training | Start, complete, finish, cancel and reset operate on coordinator state and persist only through their injected boundaries. Weight progression is a pure rule applied when an exercise finishes. |
| Exercise management | Reset-all finalizes the observed workout order, cancels active sessions and resets the workout's exercises. |
| Feedback | Saving persists non-empty per-session feedback; read operations distinguish the active session from historical feedback. |
| Friends | Import validates and isolates a share envelope; comparison loads the friend snapshot and calculates typed metrics without merging it into user data. |

## Shared Components

Shared UI lives in `FitnessUI` when it is persistence-independent. Components
that need SwiftData models or `@Query` live in `FitnessPersistenceUI`; feature-only
composition remains in the owning feature package.

| Component family | Contract and owner |
|---|---|
| Card surfaces | `CardBackground` owns neutral visual primitives, including the frameless `.plain` structure and shared `.primary` surface. `appPrimarySurface` applies that treatment to rectangle, capsule and circle controls without duplicating its palette. `CardTheme` maps feature semantics such as training idle/inactive onto those primitives. `CardShell`, `ProfileCardContainer`, `ProfileCardHeading`, profile tile surfaces, edge indicators, metric columns and set tiles define reusable card composition in `FitnessUI`; Profile consumes `.primary` without depending on a training state. Exercise model cards that bind live SwiftData state live in `FitnessPersistenceUI`. |
| Exercise cards | `IdleActiveCardModelView` and `InactiveCardModelView` expose user intents for availability, latest-entry and coaching-history loading; they do not own storage. `ActiveCardModelView` renders coordinator-backed active state. |
| Category/workout artwork | Shared stage and layout primitives in `FitnessUI` keep category and workout tiles structurally consistent without documenting their current dimensions here. |
| Training session | `TrainingSessionComponent`, set rows, timer and picker components render coordinator state. The app root owns sheet presentation; the component does not own navigation or session lifetime. |
| Editing sheets | `OverlaySheetContainer`, `SheetActionArea`, shared picker actions and editing-sheet visibility keep presentation chrome, prominent sheet-action sizing and bottom-bar suppression consistent. `ProfileActionRow` applies the same semantic secondary/primary composition with compact Profile-specific geometry; `RefreshActionButton` is its refresh-specific wrapper. Feature packages own form state and validation. |
| Feedback | `FeedbackSheetComponent` presents feature-owned feedback UI. `FeedbackViewModel` uses the coordinator-owned draft store and session-scoped persistence. |
| Menus | `MiniActionMenuView` renders caller-provided actions. Every item has a stable semantic ID; localized labels are presentation data rather than identity. |
| Workout selection | `WorkoutDropdownView` and `WorkoutPickerView` receive workout values and callbacks; they do not resolve persistence dependencies. |
| Adaptive surfaces | Shared glass/dark-surface modifiers centralize platform-version behavior so feature views do not duplicate availability branches. |
| Accessibility IDs | Cross-package identifiers live in `FitnessCore` or `FitnessUI` according to ownership and are reused by production UI and UI tests. |
| Haptics and formatting | Platform guards and common display formatting are centralized in small utilities rather than repeated at feature call sites. |

## Utilities

Utilities are stateless, broadly reused helpers. Important ownership boundaries are:

- Weight, date and timer formatting is centralized; feature views do not create
  competing format rules.
- Weight option generation returns typed values where possible; localization is
  applied when labels render.
- Safe-area access uses the shared environment key rather than global window APIs.
- User-facing strings use the established localization boundary instead of being
  promoted into architecture documentation.

## Extensions

Cross-feature extensions stay small and policy-oriented: standard toolbar
presentation, hexadecimal color construction, and the shared swipe-back modifier.
Feature-specific behavior belongs to the feature rather than a global extension.

## State & Navigation

| Owner | State responsibility |
|---|---|
| `AppRouter` | Owns `NavigationPath`, derives the current app scene and owns an independent optional `TrainingPresentation`. Views request navigation through router intents rather than mutating the path. |
| App root | Owns state that must survive destination reconstruction, including the Home Overview/List mode, shared overlay state, the router and the model container. |
| `TrainingCoordinator` | Owns one training session's active exercise, execution progress, timer and feedback draft. It contains no SwiftData models. |
| `TrainingCoordinatorCache` | Shares the category coordinator between screens and finds the coordinator for a particular exercise. |
| `UIOverlayState` | Coordinates menus, editing-sheet visibility and exercise activate/deactivate selection across the current app surface. |
| Feature view models | Own transient presentation and form state; persisted truth continues to come from models or service reads. |

`TrainingPresentation` contains only the exercise ID and category. Dismissing the
sheet does not imply cancelling the coordinator session. Real navigation-path
mutations clear the presentation so it cannot outlive its Home or Category parent.

## Navigation

`NavigationDestination` is the shared typed destination enum. The app root maps its
cases to Workouts, Home, Profile, Total Analytics, Schedule and Muscle Category
screens. `AppRouter` provides push, pop, root replacement and training-presentation
intents; views do not construct a parallel router.

The bottom bar has five semantic destinations: Workouts, Training, Analytics,
Schedule and Profile. Workouts is the list root. Home and Category belong to the
Training tab. Opening a workout from the list preserves the list beneath Home;
launching the default workout from the Training tab replaces the path with Home.
Only the former therefore exposes back navigation to the workout list.

Training is not a navigation destination. The app presents it above the existing
Home or Category hierarchy according to ADR-0014, allowing the parent query-backed
screen and the coordinator session to keep their respective state.

## AppStyle Tokens

`FitnessUI.AppStyle` is the single source of truth for spacing, typography, color,
opacity, corner radius, shadows, animation and blur. This document deliberately
does not mirror token names or values; source completion and the design-system
tests are authoritative for that implementation surface.

`DeviceLayout` owns semantic device-class and responsive-layout policy. Views use
that policy and AppStyle tokens instead of introducing local screen-width
breakpoints or raw design constants. Shared card/tile geometry belongs to its
`FitnessUI` layout component rather than to feature views.

`AppAccentScheme` is the persisted user preference for the semantic accent
palette; `FitnessAppApp` is its only `@AppStorage` owner. The root derives and
injects one immutable `AppColorTheme`. SwiftUI then invalidates environment
consumers without replacing view identity, so feature state, navigation and
in-flight work survive a palette change. Dynamic accent colors and default-icon
resolution come from that value rather than global `AppStyle.Color` or feature-
owned persistence. Fixed color primitives remain in `AppStyle.Color`.

`ProfileColorTheme` is the semantic Profile subset carried by `AppColorTheme`,
including neutral selection-state surfaces. Profile, Friends and transit views
consume these roles and shared card/tile components. Previews and snapshots
inject a deterministic app theme directly. The roles derive from the same accent
palette as Training, and both features consume the neutral `.primary` card
surface while feature state names remain independent. Semantic status colors
remain separate. ADR-0018 records the surface boundary; ADR-0019 records theme
ownership and state-preserving propagation.

`AppLanguage` is the independently persisted app-language preference. The
Profile picker derives its options and locale mapping from the localizations
bundled with the central `FitnessResources` String Catalog. Adding a language is
therefore a catalog-only change rather than a new enum case or feature-view
change. `FitnessAppApp` is its only `@AppStorage` owner and injects the mapped
`Locale` at the visual root. A package build tool uses Xcode's symbol generator
to expose catalog-derived public `AppText` symbols across SwiftPM module
boundaries; its generated Swift file is build output, never a second text
source. Non-View code receives locale or
language explicitly. Language is not part of `AppColorTheme`, a global settings
store, or an identity-reset mechanism. ADR-0020 records the catalog, fallback
and state-preserving propagation boundary.

## Live Activity

The app target owns the currently unconnected ActivityKit bridge for starting,
updating and ending a training activity. Wiring it to training coordinator
events remains a separate feature fix. `FitnessTraining` owns the Codable,
Sendable `TrainingActivityContentState`; the app's ActivityKit attributes expose
it as their nested `ContentState` type alias. This keeps the payload and its
localization compatibility tests below the host-app boundary. Shared activity
attributes and actions form the contract with the widget extension. The widget
renders those values and does not become a second owner of training-session
state. Content state carries an optional app-language code with English
fallback for older payloads.
