import XCTest

final class TrainingNavigationUITests: BaseTest {

    @MainActor
    func testListMenuOffersResetAll() throws {
        try launch(exerciseList: .defaultArmsExercise)
        tapOn(HomeIDs.listViewToggle)
        tapOn(BottomBarIDs.contextMenu)

        verifyExists(label: "Reset all")
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
    private func openListAndStartTraining() {
        verifyExists(HomeIDs.listViewToggle)
        tapOn(HomeIDs.listViewToggle)
        tapOn(MuscleCategoryIDs.startExercise)
    }

    @MainActor
    private func verifyListParent() {
        verifyExists(HomeIDs.listViewToggle)
        verifyNotExists(HomeIDs.categoryTile(for: "arms"), elementType: .button)
    }

    @MainActor
    private func verifyCategoryParent() {
        verifyExists(MuscleCategoryIDs.screen)
        verifyNotExists(HomeIDs.listViewToggle)
    }
}
