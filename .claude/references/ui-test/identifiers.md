# Accessibility Identifiers

Needed whenever a view gains or renames a testable element.

## Accessibility ID Pattern

Each SwiftUI View that needs accessibility identifiers defines an `enum AID` at the top of its struct body. This is the **source of truth** for all IDs in that view.

```swift
struct MyView: View {
    enum AID {
        static let submitButton = "id_button_submit"
        static func row(at index: Int) -> String { "id_row_\(index)" }
    }

    var body: some View {
        Button("Submit") { ... }
            .accessibilityIdentifier(AID.submitButton)
    }
}
```

The test target maintains its own copy of the ID strings in `Selectors/AccessibilityIDs.swift`. These must be kept in sync with production identifiers. If they drift, the test fails immediately -- which is the desired behavior.

### Current Test ID Enums

The production sources of truth are listed per enum in the "Defined in" column below. Cross-feature identifiers live primarily in `FitnessCore/AccessibilityIDs.swift` (hoisted at T7-0 so model-driven `FitnessPersistenceUI` views can use them without a dependency cycle), while training-view-specific identifiers live in `FitnessUI/TrainingIDs.swift`. The "Applied in" column lists the views that attach each identifier via `.accessibilityIdentifier(...)`. The test target keeps a parallel copy in `FitnessAppUITests/Selectors/AccessibilityIDs.swift` (string-equal — drift = test failure, by design).

| Test Enum | Defined in | Applied in | IDs |
|-----------|-----------|------------|-----|
| `TrainingIDs` | `FitnessCore.AccessibilityIDs`, `FitnessUI.TrainingIDs` | `TrainingSheetView`, `TrainingSessionComponent`, `BottomActionBarView`, `SimpleActiveSetView`, `CompactTimerComponent`, `FeedbackSheetComponent`, `FeedbackSheetView`, `SymptomChipsView` | training and feedback sheet/backdrop/grabber/title/muscle-icon/set-scroll IDs used by UI flows, `cancelTraining`, `doneButton`, `finishButton`, `startButton`, `allDoneButton`, `quickDoneButton`, `feedbackButton`, `controlButton(_:)`, standard `repsField(set:)` / `quickDoneSetButton(index:)`, bilateral `repsField(logicalSet:side:)` / `quickDoneSetButton(logicalSet:side:)`, `sideHeader(_:)` |
| `WorkoutPickerIDs` | `FitnessUI.WorkoutPickerIDs` | `WorkoutDropdownView`, `WorkoutPickerView` | dropdown, overlay, native wheel, and confirmation button IDs |
| `HomeIDs` | `FitnessCore.AccessibilityIDs` | `MuscleCategorySelectionView` (category tiles via `CategoryTileModelView`; view-mode content and toggle buttons) | `categoryTile(for:)`, `overviewContent`, `listContent`, `overviewViewToggle`, `listViewToggle`; list toggle label: `Exercise list` |
| `MuscleCategoryIDs` | `FitnessCore.AccessibilityIDs` | `MuscleCategoryView`, `IdleActiveCardModelView` (post-T8d; previously `IdleActiveCardView`) | `screen`, `startExercise`; start button label: `Start exercise` |
| `ExerciseIDs` | `FitnessCore.AccessibilityIDs` | `ExercisePickerView`, `ExerciseSeatPickerView`, `InactiveCardModelView` (post-T8d; previously `InactiveCardView`) | `nameLabel`, `nameField`, `seatPicker`, `fullEditContinueButton`, `fullEditSaveButton`, `bilateralToggle`, `bodyweightToggle`, `decimalWeightToggle` |
| `ExerciseCardIDs` | `FitnessCore.AccessibilityIDs` | `ExerciseCardModelView`, `IdleActiveCardModelView`, `InactiveCardModelView` (post-T8d; previously legacy snapshot views) | `completedCard(_:)`, `activeCard(_:)`, `idleCard(_:)`, card prefixes, `analytics(_:)`, `analyticsPrefix` |
| `AnalyticsIDs` | `FitnessCore.AccessibilityIDs` | `AnalyticsView`, `AddAnalyticsEntryView` | `screen`, `addDataButton`, `entryAddSetButton`, `entrySaveButton`, side-aware entry weight/reps fields, `bilateralResult(logicalSet:side:)` |
| `WorkoutAnalyticsIDs` | `FitnessCore.AccessibilityIDs` | `WorkoutAnalyticsEntryView` | `screen`, `dateButton`, `saveButton`, `exerciseSelection(_:)`, `exerciseDetails(_:)` |
| `WorkoutIDs` | `FitnessCore.AccessibilityIDs` | `WorkoutTileView`, `CreateWorkoutView` | `tilePrefix`, `settingsPrefix`, `tile(_:)`, `settings(_:)`, `createTitle`, `createNameField`, `createTypePicker`, `createSaveButton` |
| `BottomBarIDs` | `FitnessCore.AccessibilityIDs` | `BottomMenuBarView` | `contextMenu`, `workoutsTab`, `trainingTab`, `analyticsTab`, `scheduleTab`, `profileTab` |
| `ProfileIDs` | Profile and Friends view-local identifiers | `ProfileView`, `FriendsSection` | body/friends expansion evidence, BMI refresh, Friends user row and accent picker options |
