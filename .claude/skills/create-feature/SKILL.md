---
name: create-feature
description: >-
  Scaffold a new SwiftUI feature module, extend an existing feature, or create
  a picker sheet with correct project conventions. Use when the user asks to
  create a new feature, screen, page, module, view, tab, picker, calendar,
  schedule, dashboard, settings, or add functionality to an existing feature.
  Also use when asked to build a neue Seite, neues Feature, neuer Screen,
  new screen, or new page in the FitnessApp iOS project.
---

# Creating a Feature Module

## Before You Start

Read only the relevant section of `.claude/references/architecture-documentation.md`
for domain models, services, navigation, and existing shared components.

## Steps

1. **Create the feature folder** at `FitnessApp/Features/<FeatureName>/`.

2. **Create the ViewModel** — `<FeatureName>ViewModel.swift`:

```swift
import Foundation
import SwiftUI

class <FeatureName>ViewModel: ObservableObject {
    // State exposed to the View
    @Published var items: [Item] = []

    // Inject services, never instantiate singletons in Views
    private let storageService = <Service>.shared

    init() {
        // Bind to service publishers or load initial data
    }

    // All business logic lives here
    func performAction() { }
}
```

3. **Create the View** — `<FeatureName>View.swift`:

```swift
import SwiftUI

struct <FeatureName>View: View {
    @StateObject private var viewModel = <FeatureName>ViewModel()
    @Binding var navigationPath: NavigationPath

    var body: some View {
        ZStack {
            AppStyle.Color.backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView
                contentView
            }
        }
    }

    private var headerView: some View {
        Text("<Title>")
            .font(AppStyle.Font.navigationHeadline)
            .foregroundColor(AppStyle.Color.white)
            .padding(.top, AppStyle.Padding.titleTop)
            .padding(.bottom, AppStyle.Padding.titleBottom)
    }

    private var contentView: some View {
        ScrollView {
            // Use AppStyle tokens for all styling
            // Add .accessibilityIdentifier("id_<context>_<element>") to all
            // interactive elements (buttons, text fields, tappable views)
        }
        .padding(.horizontal, AppStyle.Padding.horizontal)
    }
}
```

4. **Register navigation** — add a case to `NavigationDestination` in `FitnessAppApp.swift`:

```swift
// In the enum
case <featureName>

// In .navigationDestination
case .<featureName>:
    <FeatureName>View(navigationPath: $navigationPath)
        .navigationBarBackButtonHidden(true)
        .onAppear { overlayState.currentScene = .<scene> }
```

5. **Verify placement** — not everything is a feature module. See the "Where to Place New Code" section in `.claude/references/architecture-documentation.md` for pickers, shared views, utilities, and services.

6. **Run the checklist** below before finishing.

---

## Extending an Existing Feature

When adding to an existing feature (new view, new service method, new chart type, etc.):

1. **Locate the feature folder** — check the Feature Map in `.claude/references/architecture-documentation.md`.
2. **Read existing code first** — understand the ViewModel's state and the View's structure before adding.
3. **Add to the ViewModel** — new data, new methods. Never add business logic to the View.
4. **Reuse shared components** — check the Shared Components table before building custom UI.
5. **If adding a new navigable screen** within the feature, register it in `NavigationDestination`.
6. **If changing a model** — new fields on `Codable` types must be optional or have a default value (existing JSON data will lack the field).
7. **Add accessibility identifiers** to all new interactive elements (`.accessibilityIdentifier("id_<context>_<element>")`) and matching Selector constants in `FitnessAppUITests/Selectors/`.
8. **Run the checklist** below.

---

## Creating a Picker Sheet

Pickers belong in `Features/Picker/`, not in a feature folder. Use existing picker infrastructure:

1. **Create the picker view** in `Features/Picker/<Name>PickerView.swift`.
2. **Use `OverlaySheetContainer`** as the outermost wrapper — provides backdrop, grabber, swipe-dismiss, appear animation, and `exercisePickerSheet` styling automatically.
3. **Use `ExercisePickerActionButtons`** for the Cancel/Save button row (inside the container content).
4. **Use `ExerciseWheelPickerRow`** if the picker involves sets, reps, or weight wheels.
5. **Use `ExercisePickerInputField`** for any text input inside the picker.
6. **Use `WeightOptionsGenerator`** for weight option arrays.
8. **Run the checklist** below.

---

## Checklist

- [ ] All styling uses `AppStyle` tokens (Color, Font, Padding, CornerRadius, Opacity)
- [ ] No hardcoded `Color(hex:)`, `.font(.system(...))`, numeric `.padding()`, `.cornerRadius()`, `.opacity()`
- [ ] If new font sizes/weights are needed, add tokens to `AppStyle.Font` first
- [ ] Reusable components used where applicable (see Shared Components in `.claude/references/architecture-documentation.md`)
- [ ] Weight display uses `WeightFormatter.displayWeight(_:)`
- [ ] Analytics date logic uses `AnalyticsDateHelper`
- [ ] ViewModel is `ObservableObject` with `@Published` properties
- [ ] View owns ViewModel via `@StateObject`
- [ ] No business logic in the View
- [ ] Navigation registered in `NavigationDestination` enum
- [ ] `AppCurrentScene` enum updated if new scene type
- [ ] All interactive elements (buttons, text fields, tappable views) have `.accessibilityIdentifier("id_<context>_<element>")` — see `.claude/references/ui-test/identifiers.md`
- [ ] Matching Selector constants added in `FitnessAppUITests/Selectors/<ScreenName>Selectors.swift`
- [ ] Unit tests written for ViewModel and Service logic (at minimum: initial state, main action, edge case). Place in the relevant `Packages/*/Tests/` target. New services must have a protocol so they can be mocked in tests.
- [ ] Test domain classified with `bash .claude/hooks/lib/test-domain-risk.sh classify worktree`, then test layer selected with `.claude/references/test-selection-policy.md`. Training/Exercise is blocker; Workouts and Analytics are high; Profile and Feedback are low. Add focused unit/integration coverage for meaningful behavior risk; add a snapshot only for a stable reusable visual contract whose risk reduction exceeds baseline maintenance. A `public View` alone does not require a snapshot.
- [ ] `architecture-documentation.md` updated (Feature Map, Navigation, new shared components/services)
