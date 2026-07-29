import XCTest

final class TrainingNavigationUITests: BaseTest {

    @MainActor
    func testListMenuOffersResetAll() throws {
        try launch(exerciseList: .defaultArmsExercise)
        tapOn(HomeIDs.listViewToggle)
        tapOn(BottomBarIDs.contextMenu)

        verifyExists(label: HomeLabels.resetAll)
    }

    @MainActor
    func testListStartedTrainingBackReturnsToList() throws {
        try launch(exerciseList: .defaultArmsExercise)
        openListAndStartTraining()

        tapOn(BottomBarIDs.backButton)

        verifyListParent()
    }

    @MainActor
    func testListStartedTrainingCancelReturnsToList() throws {
        try launch(exerciseList: .defaultArmsExercise)
        openListAndStartTraining()

        tapOn(TrainingIDs.cancelTraining)

        verifyListParent()
    }

    @MainActor
    func testListStartedTrainingFinishReturnsToList() throws {
        try launch(exerciseList: .defaultArmsExercise)
        openListAndStartTraining()

        finishTraining()

        verifyListParent()
        verifyExistsWithPrefix(ExerciseCardIDs.completedCardPrefix)
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
    }

    @MainActor
    func testCategoryStartedTrainingCancelReturnsToCategory() throws {
        try launch(exerciseCategory: .defaultArmsExercise)
        tapOn(MuscleCategoryIDs.startExercise)

        tapOn(TrainingIDs.cancelTraining)

        verifyCategoryParent()
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
    private func finishTraining() {
        for setIndex in 1...3 {
            tapOn(TrainingIDs.doneButton)
            waitForNonEmptyLabel(TrainingIDs.repsField(set: setIndex - 1))
        }
        tapOn(TrainingIDs.finishButton)
    }
}
