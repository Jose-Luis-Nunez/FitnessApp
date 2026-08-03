import XCTest

final class WorkoutPickerUITests: BaseTest {
    @MainActor
    func testTappingWorkoutRowSelectsItAndDismissesPicker() throws {
        try launchCategorySelection()

        verifyLabel(
            WorkoutPickerIDs.dropdown,
            equals: WorkoutLabels.pullFixture,
            elementType: .button
        )
        tapOn(WorkoutPickerIDs.dropdown)
        verifyExists(WorkoutPickerIDs.overlay)

        selectPickerWheelValue(
            WorkoutPickerIDs.wheel,
            value: WorkoutLabels.legFixture
        )
        tapSelectedPickerWheelRow(WorkoutPickerIDs.wheel)

        verifyNotExists(WorkoutPickerIDs.overlay)
        verifyLabel(
            WorkoutPickerIDs.dropdown,
            equals: WorkoutLabels.legFixture,
            elementType: .button
        )
    }
}
