import XCTest

final class BilateralExerciseFlowUITests: BaseTest {
    @MainActor
    func testFullEditCanEnableBilateralTraining() throws {
        try launch(exerciseCategory: .defaultArmsExercise)

        tapOn(ExerciseIDs.nameLabel, elementType: .any)
        tapOn(label: ExerciseLabels.continueAction)
        tapOn(ExerciseIDs.bilateralToggle, elementType: .any)
        tapOn(label: ExerciseLabels.saveAction)

        tapOn(MuscleCategoryIDs.startExercise)
        verifyExists(TrainingIDs.sideHeader("left"))
        verifyExists(TrainingIDs.sideHeader("right"))
    }

    @MainActor
    func testCreateFlowPersistsBilateralToggle() throws {
        try launch(exerciseCategory: .defaultArmsExercise)

        tapOn(BottomBarIDs.contextMenu)
        tapOn(label: ExerciseLabels.newExercise)
        fill(ExerciseIDs.nameField, with: "Alternating Curl")
        app.textFields[ExerciseIDs.nameField].typeText("\n")
        tapOn(label: ExerciseLabels.continueAction)
        tapOn(ExerciseIDs.bilateralToggle, elementType: .any)
        tapOn(label: ExerciseLabels.saveAction)

        tapOn(MuscleCategoryIDs.startExercise)
        verifyExists(TrainingIDs.sideHeader("left"))
        verifyExists(TrainingIDs.sideHeader("right"))
    }

    @MainActor
    func testSwitchingExerciseAndReturningResumesOnRightSide() throws {
        let other = TestExerciseFixture.defaultArmsExercise.with(
            name: "Crunch",
            category: "abs"
        )
        try launch(
            exerciseCategory: .bilateralTorsoExercise,
            additional: [other]
        )

        let startButtons = app.buttons.matching(
            identifier: MuscleCategoryIDs.startExercise
        )
        XCTAssertTrue(startButtons.element(boundBy: 0).waitForExistence(timeout: 5))
        startButtons.element(boundBy: 0).tap()
        tapOn(TrainingIDs.doneButton)
        waitForNonEmptyLabel(
            TrainingIDs.repsField(logicalSet: 0, side: "left")
        )
        tapOn(BottomBarIDs.backButton)

        let categoryStartButtons = app.buttons.matching(
            identifier: MuscleCategoryIDs.startExercise
        )
        XCTAssertTrue(categoryStartButtons.element(boundBy: 1).waitForExistence(timeout: 5))
        categoryStartButtons.element(boundBy: 1).tap()
        tapOn(BottomBarIDs.backButton)

        let resumedStartButtons = app.buttons.matching(
            identifier: MuscleCategoryIDs.startExercise
        )
        XCTAssertTrue(resumedStartButtons.element(boundBy: 0).waitForExistence(timeout: 5))
        resumedStartButtons.element(boundBy: 0).tap()
        tapOn(TrainingIDs.doneButton)

        waitForNonEmptyLabel(
            TrainingIDs.repsField(logicalSet: 0, side: "right")
        )
    }

    @MainActor
    func testManualBilateralAnalyticsCanBeAddedAndEdited() throws {
        let completed = TestExerciseFixture.bilateralTorsoExercise.with(
            completed: true
        )
        try launch(
            exerciseCategory: completed,
            seedAnalyticsHistory: true
        )

        tapOnWithPrefix(ExerciseCardIDs.completedCardPrefix)
        tapOnWithPrefix(ExerciseCardIDs.analyticsPrefix)
        tapOn(label: AnalyticsLabels.addData)

        let rightReps = AnalyticsIDs.entryRepsField(
            logicalSet: 0,
            side: "right"
        )
        tapOn(rightReps)
        let picker = app.pickerWheels.firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.adjust(toPickerWheelValue: "11")
        tapOn(label: "Select")
        tapOn(label: AnalyticsLabels.saveAction)

        verifyExists(
            AnalyticsIDs.bilateralResult(logicalSet: 0, side: "right")
        )
        tapOn(
            AnalyticsIDs.bilateralResult(logicalSet: 0, side: "right"),
            elementType: .any
        )
        verifyLabel(rightReps, equals: "11", elementType: .button)

        tapOn(rightReps)
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.adjust(toPickerWheelValue: "12")
        tapOn(label: "Select")
        tapOn(label: AnalyticsLabels.saveAction)
    }
}
