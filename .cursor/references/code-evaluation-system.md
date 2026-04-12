# Code Evaluation System — Fitness Tracking App (iOS/Swift)

---

## For the AI — Instructions

This file has one job: Analyze the codebase and create PROJECT_CONTEXT.md.

### When the user says `Phase 1`

1. Create `eval_tasks/` folder if it doesn't exist.
2. Create all task files (1A through 1H) from the definitions below.
3. **Parallel execution via subagents:**
   Spawn subagents for tasks 1A, 1B, 1C, 1D, 1E in parallel.
   Each subagent reads its task file and writes its section
   directly into PROJECT_CONTEXT.md.
4. **Sequential execution after subagents complete:**
   1F (Consolidate) → 1G (Validation) → 1H (Review).
5. After 1H, confirm:
   "PROJECT_CONTEXT.md complete. Ready for evaluation."

If subagents are not available, execute all tasks sequentially.

### When the user says `1A`, `1B`, etc.

Create and execute only that specific task.
Useful for updating a single section of PROJECT_CONTEXT.md.

---

## Task Definitions

Tasks 1A–1E are independent (parallel). Tasks 1F–1H are sequential.

---

### File: eval_tasks/1A_data_persistence.md

```markdown
# Task 1A — Data & Persistence

## What to do

Analyze all Model/Entity files in the project.
Write section "Data & Persistence" into PROJECT_CONTEXT.md.
If PROJECT_CONTEXT.md does not exist, create it.
If it exists, replace the "Data & Persistence" section.

## What to analyze

1. **Entity Map** — All entities with relationships (textual ER diagram)
2. **Persistence Strategy** — What is stored where and how?
3. **Weaknesses** — Missing constraints, nil risks, orphan danger, silent errors

Descriptive, not judgmental. Max 60 lines.
Start with the largest files by line count.
```

---

### File: eval_tasks/1B_architecture.md

```markdown
# Task 1B — Architecture & Dependencies

## What to do

Analyze ViewModels, Services, and Manager classes.
Append section "Architecture" to PROJECT_CONTEXT.md.

## What to analyze

1. **Pattern** — MVVM, MVC, TCA, mix? Where consistent, where not?
2. **Dependency Map** — Textual diagram. Flag circular dependencies.
3. **Concurrency** — async/await, Combine, Actors, GCD — where, consistent?
4. **Navigation** — Pattern used, navigation logic location

Max 60 lines. Start with largest files.
```

---

### File: eval_tasks/1C_ui_state.md

```markdown
# Task 1C — UI & State

## What to do

Analyze all View files.
Append section "UI & State" to PROJECT_CONTEXT.md.

## What to analyze

1. **State Inventory** — Property wrappers used, table format
2. **Duplicated State** — Same data in multiple sources of truth?
3. **Large Views** — All views >150 lines
4. **UX Patterns** — Loading, error, empty states — consistent?

Max 60 lines.
```

---

### File: eval_tasks/1D_tests.md

```markdown
# Task 1D — Tests

## What to do

Analyze all test files.
Append section "Tests" to PROJECT_CONTEXT.md.

## What to analyze

1. **Coverage** — Table: Module | Unit | UI | Integration
2. **Quality** — Mocks, fixtures, setup patterns
3. **Gaps** — Critical but untested

Max 40 lines. If no tests exist, state explicitly.
```

---

### File: eval_tasks/1E_module_discovery.md

```markdown
# Task 1E — Module & Structure Discovery

## What to do

Map the actual structure of the codebase.
Append section "Module Structure" to PROJECT_CONTEXT.md.

## What to analyze

1. **File Inventory** — All Swift files grouped by function
   (Views, ViewModels, Services, Models, Utilities, Extensions)
2. **Collaboration Map** — Which files work together?
   Group files that import each other or share types.
3. **Workflow Map** — User-facing workflows mapped to files involved.
4. **Natural Module Boundaries** — Where are the natural splits?

Max 60 lines.
```

---

### File: eval_tasks/1F_consolidate.md

```markdown
# Task 1F — Consolidate & Risks

Requires: Sections from 1A–1E must exist in PROJECT_CONTEXT.md.

## What to do

1. Remove redundancies between sections.
2. Append section "Risk Inventory" — Top 5 risks:
   - Risk: [What]
   - Trigger: [Concrete scenario]
   - Impact: [What happens]
   - Affected files: [Which]
3. Append section "Implicit Decisions":
   What was decided without documenting it?

Total PROJECT_CONTEXT.md max 300 lines.
```

---

### File: eval_tasks/1G_validation.md

```markdown
# Task 1G — Validation

Verify PROJECT_CONTEXT.md against the 5 largest Swift files.

1. What does the document claim that doesn't match the code?
2. What exists in the code that the document doesn't mention?
3. Where is the document vague where the code gives clear answers?

Apply corrections directly in PROJECT_CONTEXT.md.
```

---

### File: eval_tasks/1H_review.md

```markdown
# Task 1H — Review

Final quality gate.

## What to check

1. **Completeness** — Every section has substantive content?
   Thin sections: flag "Section [X] may need a rerun."
2. **Internal Consistency** — Sections contradict each other?
3. **Risk Inventory Quality** — Risks specific, actionable, reference real files?
4. **Gaps** — Files or modules not covered by any task?

If issues: Fix directly. List what was fixed.
If clean: "PROJECT_CONTEXT.md complete. Ready for evaluation."
```

---

## Subagent Execution Model

```
┌──────────────────────────────────────────┐
│ Parent Agent                             │
│ Creates eval_tasks/, then:               │
│                                          │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐│
│  │ 1A  │ │ 1B  │ │ 1C  │ │ 1D  │ │ 1E  ││
│  │     │ │     │ │     │ │     │ │     ││
│  └──┬──┘ └──┬──┘ └──┬──┘ └──┬──┘ └──┬──┘│
│     └───────┴───────┴───┬───┴───────┘   │
│                         ▼               │
│              1F → 1G → 1H (sequential)  │
└──────────────────────────────────────────┘
```

---

## For the User

### After Phase 1

```
📁 Project Root/
├── code-evaluation-system.md       ← This file
├── PROJECT_CONTEXT.md               ← Created by Phase 1
├── 📁 eval_tasks/                   ← Task files
```

### Next Step

Open architecture-evaluation.md in Plan Mode
and type `Evaluate` to assess the codebase.
