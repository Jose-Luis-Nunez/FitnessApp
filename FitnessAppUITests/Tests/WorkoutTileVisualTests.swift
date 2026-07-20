import XCTest

final class WorkoutTileVisualTests: BaseTest {

    @MainActor
    func testWorkoutTilesMatchCategoryTileGeometry() throws {
        try launchCategorySelection()

        let categoryTileFrames = sortFramesInReadingOrder(
            ["arms", "chest", "back", "legs"].map {
                frameOf(HomeIDs.categoryTile(for: $0), elementType: .button)
            }
        )
        attachDiagnosticScreenshot(named: "category-selection-tiles")

        tapOn(BottomBarIDs.workoutsTab)

        verifyExistsWithPrefix(WorkoutIDs.tilePrefix)
        verifyExistsWithPrefix(WorkoutIDs.settingsPrefix)
        let workoutTileFrames = framesOfElements(
            withPrefix: WorkoutIDs.tilePrefix,
            limit: 4
        )
        attachDiagnosticScreenshot(named: "workout-tiles")

        guard workoutTileFrames.count == 4, categoryTileFrames.count == 4 else {
            XCTFail("Expected two complete tile rows in both overview grids")
            return
        }
        for (workoutFrame, categoryFrame) in zip(workoutTileFrames, categoryTileFrames) {
            XCTAssertEqual(workoutFrame.width, categoryFrame.width, accuracy: 0.5)
            XCTAssertEqual(workoutFrame.height, categoryFrame.height, accuracy: 0.5)
            XCTAssertEqual(workoutFrame.minX, categoryFrame.minX, accuracy: 0.5)
            XCTAssertEqual(workoutFrame.maxX, categoryFrame.maxX, accuracy: 0.5)
        }

        let workoutColumnGap = workoutTileFrames[1].minX - workoutTileFrames[0].maxX
        let categoryColumnGap = categoryTileFrames[1].minX - categoryTileFrames[0].maxX
        XCTAssertEqual(workoutColumnGap, categoryColumnGap, accuracy: 0.5)

        let workoutRowGap = workoutTileFrames[2].minY - workoutTileFrames[0].maxY
        let categoryRowGap = categoryTileFrames[2].minY - categoryTileFrames[0].maxY
        XCTAssertEqual(workoutRowGap, categoryRowGap, accuracy: 0.5)
    }

    @MainActor
    func testCreateWorkoutOffersTypePicker() throws {
        try launchCategorySelection()
        tapOn(BottomBarIDs.workoutsTab)
        tapOn(BottomBarIDs.contextMenu)
        tapOn(label: WorkoutLabels.newWorkout)

        verifyExists(WorkoutIDs.createTitle, elementType: .staticText)
        verifyExists(WorkoutIDs.createNameField, elementType: .textField)
        verifyExists(WorkoutIDs.createTypePicker, elementType: .button)
        tapOn(WorkoutIDs.createTypePicker)

        for option in WorkoutLabels.typeOptions {
            verifyExists(label: option, timeout: TestDefaults.shortTimeout)
        }
        attachDiagnosticScreenshot(named: "create-workout-type-menu")
    }

    @MainActor
    func testCreateWorkoutRequiresNameAndTypeBeforeSaving() throws {
        try launchCategorySelection()
        tapOn(BottomBarIDs.workoutsTab)
        tapOn(BottomBarIDs.contextMenu)
        tapOn(label: WorkoutLabels.newWorkout)

        verifyIsDisabled(WorkoutIDs.createSaveButton)
        fill(WorkoutIDs.createNameField, with: "Pull")
        verifyIsDisabled(WorkoutIDs.createSaveButton)

        tapOn(WorkoutIDs.createTypePicker)
        tapOn(label: WorkoutLabels.typeOptions[0])

        verifyIsEnabled(WorkoutIDs.createSaveButton)
        attachDiagnosticScreenshot(named: "create-workout-required-fields")
    }
}
