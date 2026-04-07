---
name: creating-feature-module
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

Read [architecture.md](../../references/architecture.md) for domain models, services, navigation, and existing shared components.

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

5. **Verify placement** — not everything is a feature module. See the "Where to Place New Code" table in [architecture.md](../../references/architecture.md) for pickers, shared views, utilities, and services.

6. **Run the checklist** below before finishing.

---

## Extending an Existing Feature

When adding to an existing feature (new view, new service method, new chart type, etc.):

1. **Locate the feature folder** — check the Feature Map in [architecture.md](../../references/architecture.md).
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
2. **Use `ExercisePickerSheetModifier`** for the bottom-sheet chrome (rounded background, backdrop).
3. **Use `ExercisePickerActionButtons`** for the Cancel/Save button row.
4. **Use `ExerciseWheelPickerRow`** if the picker involves sets, reps, or weight wheels.
5. **Use `ExercisePickerInputField`** for any text input inside the picker.
6. **Use `WeightOptionsGenerator`** for weight option arrays.
7. **Present the picker** via a `.modifier(ExercisePickerSheetModifier(...))` on the parent view.
8. **Run the checklist** below.

---

## Checklist

- [ ] All styling uses `AppStyle` tokens (Color, Font, Padding, CornerRadius, Opacity)
- [ ] No hardcoded `Color(hex:)`, `.font(.system(...))`, numeric `.padding()`, `.cornerRadius()`, `.opacity()`
- [ ] If new font sizes/weights are needed, add tokens to `AppStyle.Font` first
- [ ] Reusable components used where applicable (see Shared Components table in [architecture.md](../../references/architecture.md))
- [ ] Weight display uses `WeightFormatter.displayWeight(_:)`
- [ ] Analytics date logic uses `AnalyticsDateHelper`
- [ ] ViewModel is `ObservableObject` with `@Published` properties
- [ ] View owns ViewModel via `@StateObject`
- [ ] No business logic in the View
- [ ] Navigation registered in `NavigationDestination` enum
- [ ] `AppCurrentScene` enum updated if new scene type
- [ ] All interactive elements (buttons, text fields, tappable views) have `.accessibilityIdentifier("id_<context>_<element>")` — see naming patterns in [ui-test-conventions/reference.md](../ui-test-conventions/reference.md)
- [ ] Matching Selector constants added in `FitnessAppUITests/Selectors/<ScreenName>Selectors.swift`
- [ ] `architecture.md` updated (Feature Map, Navigation, new shared components/services)
