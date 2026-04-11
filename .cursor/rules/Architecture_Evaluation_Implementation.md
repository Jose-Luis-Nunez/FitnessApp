# Architecture Evaluation & Implementation — iOS Fitness Tracking App

---

## For the AI — Instructions

This file evaluates the codebase against architecture principles
and creates implementation plans.

When you read this file, first locate and read PROJECT_CONTEXT.md.
If not found, stop: "No PROJECT_CONTEXT.md found. Run Phase 1 with Code_Evaluation_System.md first."

### Routing

| User types           | Action                                           |
|----------------------|--------------------------------------------------|
| `Evaluate`           | Full evaluation against all principles below.    |
|                      | Check every principle. Check anti-pattern table. |
|                      | Propose changes for every violation found.       |
| `Create Plan`        | After decisions are made: Create phased           |
|                      | implementation tasks in implementation_tasks/.    |
| `Quick Check`        | Fast 🟢🟡🔴 of provided diff. Max 15 lines.      |
| `Feature Review`     | Edge cases + architecture fit for named feature. |
| `Architecture Review`| Deep layer/principle analysis of provided files. |
| `Deep Dive`          | Investigate specific suspicion.                  |

### Rules

- `Quick Check`: User must provide changed files or diff.
  If not provided, ask: "Which files changed?"
- `Feature Review`: User must name the feature.
  If not named, ask: "Which feature should I review?"
- `Deep Dive`: User must describe suspicion.
  If not provided, ask: "What do you suspect is wrong?"
- Every finding must reference concrete code.
- Every violation must name the principle it breaks.
- Propose changes as Apply-ready code modifications.
- When a violation requires an implementation choice from Part 2 (Decisions),
  do NOT just list the options. For each decision, explain:
  1. What this decision affects in THIS codebase — reference specific files and services.
  2. Each option with concrete pros and cons for THIS project, not generic theory.
  3. What changes in practice: How many files are affected? What does the migration look like?
  4. A recommendation based on the evaluation findings, with reasoning.
  Ask the user to choose before proposing code.

---

## Principles (Non-Negotiable)

Based on production architecture research:
Uber, Airbnb, Lyft, Square, Revolut, Kickstarter, Spotify, Pinterest.

---

### Clean Architecture Layers

```
Presentation  →  Domain  ←  Data
```

**Presentation** depends on Domain only. Never on Data.
**Domain** depends on nothing. Zero imports except Foundation.
**Data** depends on Domain only. Never on Presentation.
**App target** is the composition root.

Each layer is a separate Swift Package (SPM local package).
The compiler prevents illegal imports.

#### Presentation Layer

- Views are declarative, stateless, max 150 lines.
- ViewModels are `@Observable` classes. No `ObservableObject`, no `@Published`.
- Views hold ViewModels with `@State`. Not `@StateObject`.
- ViewModels call Use Cases. Never repositories or persistence directly.
- No business logic in Views or ViewModels. Only presentation logic.

#### Domain Layer

- Entities are plain Swift structs. Value types.
- Use Cases are stateless. One responsibility each.
- Repository protocols defined here. Implementations in Data.
- Must compile and be testable with zero framework dependencies.

#### Data Layer

- Implements repository protocols from Domain.
- DTOs map to Domain entities at the boundary. Domain never sees DTOs.
- All framework-specific code lives here.

---

### 10 Principles

#### 1. Unidirectional Data Flow
User Action → ViewModel → Use Case → Repository → Store → ViewModel → View.
No two-way bindings between layers.

#### 2. Single Source of Truth
Every piece of data has exactly one owner. No duplicated state.

#### 3. Protocol-Based Boundaries
Every layer boundary is a protocol. No concrete type dependencies across layers.

#### 4. Dependency Inversion
Dependencies point inward: Presentation → Domain ← Data.

#### 5. Navigation Extracted from Views
Views never decide navigation. Routes are Hashable enums. State is testable.

#### 6. Dependency Injection
No singletons. No shared mutable global state. Constructor injection default.

#### 7. Offline-First
Local database is source of truth. Views never touch network.
App works without connectivity.

#### 8. Explicit Error Handling
No `try?`. Errors propagate to meaningful handlers. User feedback or logging.

#### 9. Thread Safety by Design
Actors for storage/sync. @MainActor for UI. No unprotected shared mutable state.

#### 10. Testability as Architecture
Hard to test = wrong architecture. Domain 100% testable. ViewModels mockable.

---

### State Management (iOS 17+)

| Wrapper       | Use for                                  |
|---------------|------------------------------------------|
| `@State`      | View-local state AND ViewModel ownership |
| `@Bindable`   | Bindings from @Observable objects        |
| `@Environment`| Shared dependencies into Views           |
| `@Observable` | All ViewModels and shared state objects  |

Never `@StateObject`, `@ObservedObject`, `@EnvironmentObject` in new code.
Avoid Combine for new async work. Use async/await.

### Concurrency (Swift 6.2)

@MainActor default. `@concurrent` for CPU-heavy work only.
Actors for sync/persistence. No GCD. `.task` modifier for async in Views.

---

### Anti-Patterns — Always 🔴

| Anti-Pattern | Why it breaks |
|---|---|
| `try?` swallowing errors | Silent data loss |
| JSON files as database | No queries, migrations, integrity |
| Multiple VMs sharing same data source | Stale UI, race conditions |
| Business logic in Views | Untestable, duplicated |
| ViewModel calling network/persistence directly | Layer violation |
| Singletons for shared state | Hidden dependencies |
| `@StateObject`/`@ObservedObject` in new code | Loses property-level observation |
| Navigation logic in Views | Untestable, no deep linking |
| GCD / DispatchQueue | Legacy, no structured cancellation |
| Combine for new async work | Being replaced |
| `DateFormatter` in computed properties | 2-5ms per render |
| `ForEach` with index iteration | O(n²) diffing |
| Unprotected shared mutable state | Race conditions |
| `@Environment` not re-injected in sheets | Runtime crashes |

---

## Evaluation Types

---

### Evaluate — Full Assessment

Check PROJECT_CONTEXT.md against every principle above.

For each principle:
- 🟢 if followed correctly — cite the code that proves it.
- 🟡 if partially followed — explain what's missing.
- 🔴 if violated — name the principle, name the file, explain the violation.

Check every item in the anti-pattern table.
Every match is 🔴.

If violations require a decision from the Decisions section below,
do NOT just reference the decision number. Instead:
1. Explain which files in this project are affected by the decision.
2. For each option: What does it mean concretely for this codebase?
   How many files change? What does the migration look like?
3. Give a recommendation based on what the evaluation found.
4. Ask the user to choose before proceeding.

End with a summary table and the list of Decisions that need answers.
After the user answers the Decisions, they will say `Create Plan`
to generate the phased implementation tasks.

---

### Quick Check — After Code Sessions

Rate provided diff or changed files:

🟢 SOLID — well done and why
🟡 FRAGILE — works now, will break because: [specific]
🔴 VIOLATION — principle name, file, proposed fix

Max 15 lines. Every finding references concrete code.

---

### Feature Review — After Feature Implementation

User provides: Feature name + what it should do.

**Analysis A: Edge Cases**

| Input/State | Expected | Actual | Problem? |

Mandatory scenarios:
- First use (empty DB)
- Extreme values (999kg, 0 reps, negative numbers)
- Interruption (app killed during active session)
- Offline
- Timezone change during active session
- Feature-specific scenarios

**Analysis B: Architecture Fit**

1. Which principles does this feature follow?
2. Which does it violate? Principle name, file, proposed fix.
3. Does it match documented patterns in PROJECT_CONTEXT.md?
4. Does it worsen or mitigate a risk from the Risk Inventory?

---

### Architecture Review — Before Merge

Evaluate provided files:

1. **Layer Violations** — Code crossing boundaries?
2. **Principle Violations** — Which of the 10, with proposed fix.
3. **Anti-Pattern Match** — Every match is 🔴.
4. **iOS/Swift Specific**
   - Retain cycles (closures without [weak self])
   - Main thread violations
   - Actor/thread safety
   - Correct property wrapper usage
5. **Undecided Choices** — Does code assume an implementation decision
   that hasn't been made? Present options from Decisions below with
   project-specific context, affected files, and recommendation.

---

### Deep Dive — On Specific Suspicion

User provides: What they suspect.

1. Confirm or disprove with code references.
2. If confirmed: Root cause, not symptom.
3. Which principle is violated?
4. Proposed fix with affected files.

---

## Decisions (To Be Made)

Implementation choices. Each has valid options.
When presenting a decision to the user:
- Reference the specific files, services, and patterns found in PROJECT_CONTEXT.md.
- Explain each option in terms of THIS project, not abstract theory.
- Quantify: How many files change? What breaks during migration?
- Give a recommendation with reasoning based on evaluation findings.
- Ask the user to choose. Record chosen option in the Decision field.

---

### Decision 1: Persistence Framework

**What this affects in this project:**
Reference the specific storage files (e.g., WorkoutStorageService, ExerciseStorageService,
AnalyticsStorageService) and explain what happens to each under each option.

**Options:**
- **SwiftData** — Modern, Swift-native, less boilerplate.
  Pro: Simpler API, CloudKit sync, works with @Observable.
  Con: iOS 17+ only, less mature, fewer escape hatches for complex queries.
  For this project: [Explain migration path for current JSON/UserDefaults storage]
- **CoreData** — Battle-tested, full control.
  Pro: Mature, flexible, NSFetchedResultsController.
  Con: Verbose, ObjC heritage, threading complexity with NSManagedObjectContext.
  For this project: [Explain migration path for current JSON/UserDefaults storage]

**Impact:** Affects entire Data layer. Hard to switch later.
**Recommendation:** [Based on evaluation findings, explain which is better for this project and why]
**Decision:** ___

---

### Decision 2: DI Container

**What this affects in this project:**
Reference every singleton found (e.g., WorkoutStorageService.shared,
SessionTrainingCache.shared) and every ViewModel that creates its own dependencies.
Explain how each option replaces these patterns.

**Options:**
- **Constructor Injection only** — No library.
  Pro: Zero dependencies, explicit, easy to understand.
  Con: Init parameter lists grow as app grows. Manual wiring in composition root.
  For this project: [How many inits change? How complex is the composition root?]
- **Factory (hmlongco/Factory)** — Lightweight container.
  Pro: Compile-time safe, SwiftUI-compatible, works with @Observable and @MainActor.
  Con: External dependency. Learning curve for container registration.
  For this project: [How does this replace .shared patterns? Show concrete example.]
- **swift-dependencies (pointfreeco)** — Testability-focused.
  Pro: Excellent test ergonomics, @Dependency property wrapper.
  Con: Tighter coupling to Point-Free ecosystem.
  For this project: [How does this compare given current test coverage?]

**Impact:** How ViewModels and Services receive dependencies. Affects testability.
**Recommendation:** [Based on singleton count and test goals, explain which fits best]
**Decision:** ___

---

### Decision 3: Navigation Pattern

**What this affects in this project:**
Reference the current AppRouter implementation and explain what changes.
The evaluation found navigation is already centralized (GREEN) —
this decision is about migrating AppRouter to @Observable.

**Options:**
- **@Observable Coordinator** — Migrate current AppRouter to @Observable.
  Pro: Testable, deep linking, consistent with @Observable migration.
  Con: Requires updating all navigation call sites.
  For this project: [How many files reference AppRouter? What changes?]
- **Keep current AppRouter as ObservableObject** — Defer migration.
  Pro: No immediate work, navigation already works.
  Con: Inconsistent with @Observable migration, keeps Combine dependency.
  For this project: [What is the cost of deferring?]

**Impact:** Navigation consistency, Combine removal.
**Recommendation:** [Based on current AppRouter assessment]
**Decision:** ___

---

### Decision 4: Modularization

**What this affects in this project:**
Reference the current SPM package structure found in PROJECT_CONTEXT.md.
Explain how each option builds on or changes what already exists.

**Options:**
- **Add Domain package layer to existing structure** — Keep current feature packages,
  add a Domain package for Use Cases and Repository protocols.
  Pro: Compiler-enforced Use Case boundaries, incremental change.
  Con: New package to manage, need to move entity types.
  For this project: [Which types move to Domain? How many import statements change?]
- **Full SPM per feature with layers** — Each feature gets Domain/Data/Presentation.
  Pro: Maximum independence per feature.
  Con: Significant restructuring, more packages.
  For this project: [Is this overkill for current feature count?]
- **Keep current structure, add folder-based layers** — Logical separation only.
  Pro: Minimal disruption.
  Con: No compiler enforcement. Layer violations remain invisible.
  For this project: [Given 11 RED anti-patterns, is soft enforcement enough?]

**Impact:** How strictly architecture is enforced by the compiler.
**Recommendation:** [Based on current package structure and violation count]
**Decision:** ___

---

## Create Implementation Plan

When the user says `Create Plan`:

### Prerequisites

1. An evaluation must have been completed (Evaluate, Architecture Review, or Deep Dive).
2. All Decisions in Part 2 must have a chosen option filled in.
   If any Decision field is still `___`, stop and ask:
   "Decision [X] is not yet made. Please choose an option first."

### What to do

1. Read the evaluation findings (🔴 and 🟡 items).
2. Read the chosen Decisions.
3. Read PROJECT_CONTEXT.md for current codebase structure.
4. Create `implementation_tasks/` folder.
5. Break the work into **phases**. Each phase is a folder.
   Phases have dependencies — a later phase may depend on an earlier one.
   Tasks within a phase are independent and can run in parallel.

### Phase Structure

Order phases by dependency — later phases build on earlier ones:

```
📁 implementation_tasks/
├── index.md                          ← Phase overview + execution order
├── 📁 phase_1_[name]/
│   ├── task_01_[description].md
│   ├── task_02_[description].md
│   └── ...
├── 📁 phase_2_[name]/
│   ├── task_01_[description].md
│   └── ...
└── 📁 phase_3_[name]/
    └── ...
```

### index.md Format

```markdown
# Implementation Plan

## Phase Overview
- Phase 1: [Name] — [What it achieves] — [X tasks, Y parallel]
- Phase 2: [Name] — [What it achieves] — [X tasks, Y parallel]
- Phase 3: [Name] — [What it achieves] — [X tasks, Y parallel]

## Execution Order
Phase 1 must complete before Phase 2.
Phase 2 must complete before Phase 3.
Tasks within each phase are independent — execute in parallel.

## How to Execute
Open a new chat per phase.
Drag this file + all task files from the phase folder.
Say: "Execute all tasks in this phase."
```

### Task File Format

Each task file must be self-contained. It must include:
- What to change (specific files, specific code)
- Why (which principle/anti-pattern it fixes)
- Dependencies (what must exist before this task runs)
- Acceptance criteria (how to verify the change is correct)

The task file IS the context. A new chat with only this file
and the affected code files must be enough to execute it.

### Phase Naming

Name phases based on what they achieve, not what they fix.
Typical phase order for architecture migration:

```
Phase 1: Foundation     → Domain layer, persistence, core protocols
Phase 2: Rewiring       → Use Cases, DI, ViewModel refactoring
Phase 3: Modernization  → @Observable migration, Combine removal, Actors
Phase 4: Cleanup        → Remove deprecated code, update tests
```

Actual phases depend on evaluation findings and chosen decisions.

### After Creating

Report to user:
"Created [N] phases with [M] total tasks in implementation_tasks/.
 Start with Phase 1: Open a new chat, drag index.md + phase_1 tasks."

---

## Reference Codebases

- `kudoleh/iOS-Clean-Architecture-MVVM` — Clean Architecture + MVVM
- `nalexn/clean-architecture-swiftui` — Clean Architecture + SwiftUI
- `kickstarter/ios-oss` — MVVM + FRP
- `element-hq/element-x-ios` — Production SwiftUI at scale
- `tailec/ios-architecture` — Same app, 5 patterns compared

---

## For the User — Workflow

```
Step 1:  Code_Evaluation_System.md → Agent Mode → "Phase 1"
         → Creates PROJECT_CONTEXT.md

Step 2:  Architecture_Evaluation_Implementation.md → Plan Mode → "Evaluate"
         → Reads PROJECT_CONTEXT.md automatically
         → 🟢🟡🔴 Findings + Decisions presented
         → Answer the Decisions

Step 3:  Architecture_Evaluation_Implementation.md → Plan Mode → "Create Plan"
         → Creates implementation_tasks/ with phased task files

Step 4:  New chat per phase:
         → Drag index.md + phase folder tasks → Agent Mode
         → "Execute all tasks in this phase"
         → Repeat for each phase

Daily:   Architecture_Evaluation_Implementation.md → Plan Mode → "Quick Check" + diff
         → 🟢🟡🔴 → Apply
```