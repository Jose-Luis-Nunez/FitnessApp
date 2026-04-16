import Testing
import Foundation
import FitnessCore
@testable import FitnessExercise

@Suite("ExerciseFormViewModel")
@MainActor
struct ExerciseFormViewModelTests {

    private func makeSUT() -> ExerciseFormViewModel {
        ExerciseFormViewModel()
    }

    // MARK: - Initial State

    @Test func initialStateHasDefaultValues() {
        let sut = makeSUT()
        #expect(sut.showForm == false)
        #expect(sut.name.isEmpty)
        #expect(sut.weight == 0.0)
        #expect(sut.reps == 1)
        #expect(sut.sets == 1)
        #expect(sut.seat.isEmpty)
        #expect(sut.noSeats == false)
        #expect(sut.editingExercise == nil)
        #expect(sut.selectedIconName.isEmpty)
        #expect(sut.editMode == .full)
    }

    // MARK: - isFormValid

    @Test func formIsInvalidWhenNameIsEmpty() {
        let sut = makeSUT()
        sut.name = ""
        sut.reps = 10
        sut.sets = 3
        #expect(sut.isFormValid == false)
    }

    @Test func formIsInvalidWhenRepsIsZero() {
        let sut = makeSUT()
        sut.name = "Curl"
        sut.reps = 0
        sut.sets = 3
        #expect(sut.isFormValid == false)
    }

    @Test func formIsInvalidWhenSetsIsZero() {
        let sut = makeSUT()
        sut.name = "Curl"
        sut.reps = 10
        sut.sets = 0
        #expect(sut.isFormValid == false)
    }

    @Test func formIsValidWithNameAndPositiveRepsAndSets() {
        let sut = makeSUT()
        sut.name = "Curl"
        sut.reps = 10
        sut.sets = 3
        #expect(sut.isFormValid == true)
    }

    // MARK: - clearForm

    @Test func clearFormResetsAllFields() {
        let sut = makeSUT()
        sut.name = "Test"
        sut.weight = 50
        sut.reps = 12
        sut.sets = 4
        sut.seat = "3"
        sut.noSeats = true
        sut.showForm = true
        sut.editMode = .weight

        sut.clearForm()

        #expect(sut.name.isEmpty)
        #expect(sut.weight == 0.0)
        #expect(sut.reps == 1)
        #expect(sut.sets == 1)
        #expect(sut.seat.isEmpty)
        #expect(sut.noSeats == false)
        #expect(sut.editingExercise == nil)
        #expect(sut.editMode == .full)
        #expect(sut.showForm == false)
    }

    // MARK: - toggleForm

    @Test func toggleFormOpensForm() {
        let sut = makeSUT()
        sut.toggleForm()
        #expect(sut.showForm == true)
    }

    @Test func toggleFormClosesAndClearsForm() {
        let sut = makeSUT()
        sut.showForm = true
        sut.name = "Test"

        sut.toggleForm()

        #expect(sut.showForm == false)
        #expect(sut.name.isEmpty)
    }

    // MARK: - createOrUpdateExercise (new)

    @Test func createExerciseReturnsNilWhenFormInvalid() {
        let sut = makeSUT()
        sut.name = ""
        #expect(sut.createOrUpdateExercise() == nil)
    }

    @Test func createExerciseReturnsNewExercise() throws {
        let sut = makeSUT()
        sut.name = "Bench Press"
        sut.weight = 80
        sut.reps = 8
        sut.sets = 4
        sut.seat = "3"
        sut.selectedCategory = .chest

        let exercise = try #require(sut.createOrUpdateExercise())
        #expect(exercise.name == "Bench Press")
        #expect(exercise.weight == 80)
        #expect(exercise.reps == 8)
        #expect(exercise.sets == 4)
        #expect(exercise.seatSetting == "3")
        #expect(exercise.category == .chest)
    }

    @Test func createExerciseUsesDefaultIconWhenNoneSelected() {
        let sut = makeSUT()
        sut.name = "Curl"
        sut.selectedCategory = .arms
        sut.selectedIconName = ""

        let exercise = sut.createOrUpdateExercise()
        #expect(exercise?.iconName == MuscleCategoryGroup.arms.defaultIconName)
    }

    @Test func createExerciseUsesSelectedIcon() {
        let sut = makeSUT()
        sut.name = "Curl"
        sut.selectedCategory = .arms
        sut.selectedIconName = "bicepsIcon"

        let exercise = sut.createOrUpdateExercise()
        #expect(exercise?.iconName == "bicepsIcon")
    }

    @Test func createExerciseSetsSeatToNilWhenEmpty() {
        let sut = makeSUT()
        sut.name = "Curl"
        sut.seat = ""

        let exercise = sut.createOrUpdateExercise()
        #expect(exercise?.seatSetting == nil)
    }

    @Test func createExercisePreservesNoSeatsFlag() {
        let sut = makeSUT()
        sut.name = "Curl"
        sut.noSeats = true

        let exercise = sut.createOrUpdateExercise()
        #expect(exercise?.noSeats == true)
    }

    // MARK: - createOrUpdateExercise (edit existing)

    @Test func updateExercisePreservesId() {
        let sut = makeSUT()
        let original = Exercise(
            name: "Curl", weight: 10, reps: 10, sets: 3,
            iconName: "defaultArmsIcon", category: .arms
        )
        sut.editingExercise = original
        sut.name = "Updated Curl"
        sut.weight = 15
        sut.reps = 12
        sut.sets = 4
        sut.selectedCategory = .arms

        let result = sut.createOrUpdateExercise()
        #expect(result?.id == original.id)
        #expect(result?.name == "Updated Curl")
        #expect(result?.weight == 15)
    }

    @Test func updateExercisePreservesCompletedStatus() {
        let sut = makeSUT()
        let original = Exercise(
            name: "Curl", weight: 10, reps: 10, sets: 3,
            isCompleted: true, iconName: "defaultArmsIcon", category: .arms
        )
        sut.editingExercise = original
        sut.name = "Updated"
        sut.selectedCategory = .arms

        let result = sut.createOrUpdateExercise()
        #expect(result?.isCompleted == true)
    }

    // MARK: - loadExercise

    @Test func loadExercisePopulatesFormFields() {
        let sut = makeSUT()
        let exercise = Exercise(
            name: "Bench", weight: 80, reps: 8, sets: 4,
            seatSetting: "5", noSeats: false,
            iconName: "chestPressIcon", category: .chest
        )

        sut.loadExercise(exercise, category: .chest)

        #expect(sut.name == "Bench")
        #expect(sut.weight == 80)
        #expect(sut.reps == 8)
        #expect(sut.sets == 4)
        #expect(sut.seat == "5")
        #expect(sut.noSeats == false)
        #expect(sut.editingExercise?.id == exercise.id)
        #expect(sut.selectedCategory == .chest)
        #expect(sut.selectedIconName == "chestPressIcon")
    }

    @Test func loadExerciseWithNilClearsForm() {
        let sut = makeSUT()
        sut.name = "Previous"
        sut.weight = 50

        sut.loadExercise(nil, category: .arms)

        #expect(sut.name.isEmpty)
        #expect(sut.weight == 0.0)
        #expect(sut.editingExercise == nil)
        #expect(sut.selectedCategory == .arms)
    }

    @Test func loadExerciseWithInvalidIconFallsBackToDefault() {
        let sut = makeSUT()
        let exercise = Exercise(
            name: "Test", weight: 10, reps: 10, sets: 3,
            iconName: "nonexistentIcon", category: .arms
        )

        sut.loadExercise(exercise, category: .arms)

        #expect(sut.selectedIconName == MuscleCategoryGroup.arms.defaultIconName)
    }

    @Test func loadExerciseWithNilSeatSettingSetsSeatToEmpty() {
        let sut = makeSUT()
        let exercise = Exercise(
            name: "Test", weight: 10, reps: 10, sets: 3,
            seatSetting: nil, iconName: "defaultArmsIcon", category: .arms
        )

        sut.loadExercise(exercise, category: .arms)

        #expect(sut.seat.isEmpty)
    }
}
