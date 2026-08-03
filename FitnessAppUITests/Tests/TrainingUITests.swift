import XCTest

final class TrainingUITests: BaseTest {

    @MainActor
    func testFullTrainingFlow() throws {
        try launch(exerciseCategory: .defaultArmsExercise)
        tapOn(MuscleCategoryIDs.startExercise)

        verifyExists(TrainingIDs.sheet)
        verifyExists(MuscleCategoryIDs.screen)
        verifyLabel(
            TrainingIDs.sheetBackdrop,
            equals: TrainingLabels.closeTraining,
            elementType: .button
        )
        verifyLabel(
            TrainingIDs.sheetGrabber,
            equals: TrainingLabels.closeTraining
        )
        verifyLabel(
            TrainingIDs.repsField(set: 0),
            equals: TrainingLabels.recordSetResult,
            elementType: .button
        )
        verifyLabel(
            TrainingIDs.muscleIcon,
            equals: TrainingLabels.muscleIllustration
        )

        for setIndex in 1...3 {
            tapOn(TrainingIDs.doneButton)
            waitForNonEmptyLabel(TrainingIDs.repsField(set: setIndex - 1))
        }

        tapOn(TrainingIDs.finishButton)
        verifyNotExists(TrainingIDs.sheet)
    }

    @MainActor
    func testEditableMuscleArtworkOpensAndCancelsSeatPicker() throws {
        try launch(
            exerciseCategory: .defaultArmsExercise.with(noSeats: false)
        )
        tapOn(MuscleCategoryIDs.startExercise)

        tapOn(TrainingIDs.muscleIcon)
        verifyExists(ExerciseIDs.seatPicker)

        tapOn(label: ExerciseLabels.cancelAction, elementType: .button)
        verifyNotExists(ExerciseIDs.seatPicker)
        verifyExists(TrainingIDs.sheet)
    }

    @MainActor
    func testBilateralTrainingCompletesLeftAndRightForEveryLogicalSet() throws {
        try launch(exerciseCategory: .bilateralTorsoExercise)
        tapOn(MuscleCategoryIDs.startExercise)

        verifyExists(TrainingIDs.sideHeader("left"))
        verifyExists(TrainingIDs.sideHeader("right"))

        for logicalSet in 0..<3 {
            for side in ["left", "right"] {
                tapOn(TrainingIDs.doneButton)
                waitForNonEmptyLabel(
                    TrainingIDs.repsField(logicalSet: logicalSet, side: side)
                )
                if logicalSet < 2 || side == "left" {
                    verifyNotExists(TrainingIDs.finishButton)
                }
            }
        }

        verifyExists(TrainingIDs.finishButton)
        tapOn(TrainingIDs.finishButton)
        verifyNotExists(TrainingIDs.sheet)

        tapOnWithPrefix(ExerciseCardIDs.completedCardPrefix)
        tapOnWithPrefix(ExerciseCardIDs.analyticsPrefix)

        verifyExists(AnalyticsIDs.screen)
        for logicalSet in 0..<3 {
            verifyExists(
                AnalyticsIDs.bilateralResult(logicalSet: logicalSet, side: "left")
            )
            verifyExists(
                AnalyticsIDs.bilateralResult(logicalSet: logicalSet, side: "right")
            )
        }
    }

    @MainActor
    func testTenSetsScrollOnlyInsideSetColumn() throws {
        try launch(exerciseCategory: .defaultArmsExercise.with(sets: 10))
        tapOn(MuscleCategoryIDs.startExercise)

        let titleFrame = frameOf(TrainingIDs.sheetTitle)
        let timerFrame = frameOf(TrainingIDs.cancelTraining)
        let actionFrame = frameOf(TrainingIDs.doneButton)

        swipeUpOn(TrainingIDs.setScroll)
        swipeUpOn(TrainingIDs.setScroll)

        let scrollFrame = frameOf(TrainingIDs.setScroll)
        let finalSetFrame = frameOf(TrainingIDs.repsField(set: 9))
        XCTAssertGreaterThan(
            finalSetFrame.intersection(scrollFrame).height,
            0,
            "Set 10 must be visible inside the bounded set scroller"
        )
        XCTAssertEqual(frameOf(TrainingIDs.sheetTitle).minY, titleFrame.minY, accuracy: 1)
        XCTAssertEqual(frameOf(TrainingIDs.cancelTraining).minY, timerFrame.minY, accuracy: 1)
        XCTAssertEqual(frameOf(TrainingIDs.doneButton).minY, actionFrame.minY, accuracy: 1)
    }
}
