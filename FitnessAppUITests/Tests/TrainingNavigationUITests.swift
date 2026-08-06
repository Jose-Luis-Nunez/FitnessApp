import XCTest

final class TrainingNavigationUITests: BaseTest {

    @MainActor
    func testListCompletedCardLoadsSeededLatestRunWhenExpanded() throws {
        var config = UITestLaunchConfig.exerciseList(
            .defaultArmsExercise.with(completed: true)
        )
        config.seedAnalyticsHistory = true
        app.launchEnvironment["UITEST_CONFIG"] = try config.jsonString()
        app.launch()

        tapOn(HomeIDs.listViewToggle)
        expandCompletedCardAndVerifyLatestRun(reps: 10)
    }

    @MainActor
    func testCategoryCompletedCardLoadsSeededLatestRunWhenExpanded() throws {
        try launch(
            exerciseCategory: .defaultArmsExercise.with(completed: true),
            seedAnalyticsHistory: true
        )

        expandCompletedCardAndVerifyLatestRun(reps: 10)
    }

    @MainActor
    func testListMenuOffersResetAll() throws {
        try launch(exerciseList: .defaultArmsExercise)
        tapOn(HomeIDs.listViewToggle)
        tapOn(BottomBarIDs.contextMenu)

        verifyExists(label: HomeLabels.resetAll)
    }

    @MainActor
    func testListStartedTrainingBackdropDismissesToList() throws {
        try launch(exerciseList: .defaultArmsExercise)
        openListAndStartTraining()

        tapOn(TrainingIDs.sheetBackdrop)

        verifyListParent()
        verifyNotExists(TrainingIDs.sheet)
    }

    @MainActor
    func testListStartedTrainingBackDismissesToList() throws {
        try launch(exerciseList: .defaultArmsExercise)
        openListAndStartTraining()

        tapOn(BottomBarIDs.backButton)

        verifyListParent()
        verifyNotExists(TrainingIDs.sheet)
    }

    @MainActor
    func testListStartedTrainingCancelReturnsToList() throws {
        try launch(exerciseList: .defaultArmsExercise)
        openListAndStartTraining()

        tapOn(TrainingIDs.cancelTraining)

        verifyListParent()
        verifyNotExists(TrainingIDs.sheet)
    }

    @MainActor
    func testListStartedTrainingFinishReturnsToListAndLoadsLatestRunWhenExpanded() throws {
        try launch(exerciseList: .defaultArmsExercise)
        openListAndStartTraining()

        finishTraining()

        verifyListParent()
        verifyExistsWithPrefix(ExerciseCardIDs.completedCardPrefix)
        expandCompletedCardAndVerifyLatestRun(reps: 10)
    }

    @MainActor
    func testListModeSurvivesToggleRoundTripAndTrainingFinish() throws {
        try launch(exerciseList: .defaultArmsExercise)
        verifyOverviewParent()

        tapOn(HomeIDs.listViewToggle)
        verifyListParent()
        tapOn(HomeIDs.overviewViewToggle)
        verifyOverviewParent()
        tapOn(HomeIDs.listViewToggle)
        tapOn(MuscleCategoryIDs.startExercise)

        finishTraining()

        verifyListParent()
    }

    @MainActor
    func testCategoryStartedTrainingBackReturnsToCategory() throws {
        try launch(exerciseCategory: .defaultArmsExercise)
        tapOn(MuscleCategoryIDs.startExercise)

        tapOn(BottomBarIDs.backButton)

        verifyCategoryParent()
        verifyNotExists(TrainingIDs.sheet)
    }

    @MainActor
    func testCategoryStartedTrainingSwipeDownReturnsToCategory() throws {
        try launch(exerciseCategory: .defaultArmsExercise)
        tapOn(MuscleCategoryIDs.startExercise)

        swipeDownOn(TrainingIDs.sheetGrabber)

        verifyCategoryParent()
        verifyNotExists(TrainingIDs.sheet)
    }

    @MainActor
    func testDismissedTrainingResumesExistingProgress() throws {
        try launch(exerciseCategory: .defaultArmsExercise)
        tapOn(MuscleCategoryIDs.startExercise)
        tapOn(TrainingIDs.doneButton)
        waitForNonEmptyLabel(TrainingIDs.repsField(set: 0))

        tapOn(TrainingIDs.sheetBackdrop)
        tapOn(MuscleCategoryIDs.startExercise)

        verifyExists(TrainingIDs.sheet)
        waitForNonEmptyLabel(TrainingIDs.repsField(set: 0))
    }

    @MainActor
    func testCategoryStartedTrainingCancelReturnsToCategory() throws {
        try launch(exerciseCategory: .defaultArmsExercise)
        tapOn(MuscleCategoryIDs.startExercise)

        tapOn(TrainingIDs.cancelTraining)

        verifyCategoryParent()
        verifyNotExists(TrainingIDs.sheet)
    }

    @MainActor
    func testCategoryStartedTrainingFinishReturnsToCategory() throws {
        try launch(exerciseCategory: .defaultArmsExercise)
        tapOn(MuscleCategoryIDs.startExercise)

        finishTraining()

        verifyCategoryParent()
    }

    @MainActor
    func testCategoryFinishThenListFinishReturnsToList() throws {
        try launch(exerciseCategory: .defaultArmsExercise)
        tapOn(MuscleCategoryIDs.startExercise)
        finishTraining()
        verifyCategoryParent()

        tapOn(BottomBarIDs.backButton)
        verifyOverviewParent()
        tapOn(HomeIDs.listViewToggle)
        tapOn(BottomBarIDs.contextMenu)
        tapOn(label: HomeLabels.resetAll)
        tapOn(MuscleCategoryIDs.startExercise)
        finishTraining()

        verifyListParent()
    }

    @MainActor
    private func openListAndStartTraining() {
        verifyExists(HomeIDs.listViewToggle)
        tapOn(HomeIDs.listViewToggle)
        tapOn(MuscleCategoryIDs.startExercise)
    }

    @MainActor
    private func verifyListParent() {
        verifyExists(HomeIDs.listViewToggle)
        verifyExists(HomeIDs.listContent)
        verifyNotExists(HomeIDs.overviewContent)
    }

    @MainActor
    private func verifyOverviewParent() {
        verifyExists(HomeIDs.overviewViewToggle)
        verifyExists(HomeIDs.overviewContent)
        verifyNotExists(HomeIDs.listContent)
    }

    @MainActor
    private func verifyCategoryParent() {
        verifyExists(MuscleCategoryIDs.screen)
        verifyNotExists(HomeIDs.listViewToggle)
    }

    @MainActor
    private func expandCompletedCardAndVerifyLatestRun(reps: Int) {
        tapOnWithPrefix(ExerciseCardIDs.completedCardPrefix)
        verifyExists(label: "\(reps) reps", elementType: .staticText)
    }

    @MainActor
    private func finishTraining() {
        for setIndex in 1...3 {
            tapOn(TrainingIDs.doneButton)
            waitForNonEmptyLabel(TrainingIDs.repsField(set: setIndex - 1))
        }
        tapOn(TrainingIDs.finishButton)
        verifyNotExists(TrainingIDs.sheet)
    }
}
