import XCTest

final class WorkoutAnalyticsEntryUITests: BaseTest {
    @MainActor
    func testSavingWorkoutAnalyticsDismissesAndPersistsEntry() throws {
        try launch(exerciseList: .defaultArmsExercise)
        tapOn(BottomBarIDs.workoutsTab)
        tapOnWithPrefix(WorkoutIDs.settingsPrefix, elementType: .button)
        tapOn(label: WorkoutLabels.addAnalytics)

        verifyExists(WorkoutAnalyticsIDs.screen)
        verifyIsEnabled(WorkoutAnalyticsIDs.saveButton)
        verifyValueContainsWithPrefix(
            WorkoutAnalyticsIDs.exerciseSelectionPrefix,
            expectedComponents: [
                "Arms",
                "15 kilograms",
                "3 sets",
                "10 reps",
            ],
            elementType: .button
        )
        tapOnWithPrefix(
            WorkoutAnalyticsIDs.exerciseSelectionPrefix,
            elementType: .button
        )
        verifyIsDisabled(WorkoutAnalyticsIDs.saveButton)
        tapOnWithPrefix(
            WorkoutAnalyticsIDs.exerciseSelectionPrefix,
            elementType: .button
        )
        verifyIsEnabled(WorkoutAnalyticsIDs.saveButton)
        tapOn(WorkoutAnalyticsIDs.saveButton)
        verifyNotExists(WorkoutAnalyticsIDs.screen)

        tapOnWithPrefix(WorkoutIDs.tilePrefix, elementType: .button)
        tapOn(HomeIDs.listViewToggle)
        tapOnWithPrefix(ExerciseCardIDs.idleCardPrefix)
        tapOnWithPrefix(ExerciseCardIDs.analyticsPrefix)

        verifyExists(AnalyticsIDs.screen)
        verifyNotExists(AnalyticsIDs.addDataButton)
    }
}
