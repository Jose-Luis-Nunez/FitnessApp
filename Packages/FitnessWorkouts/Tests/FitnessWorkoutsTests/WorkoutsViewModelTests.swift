import Testing
import Foundation
import FitnessCore
import FitnessStorage
import FitnessTestSupport
@testable import FitnessWorkouts

@Suite("WorkoutsViewModel", .tags(.fast))
@MainActor
struct WorkoutsViewModelTests {

    private enum StubError: Error {
        case persistenceFailed
    }

    // MARK: - Setup

    @MainActor
    private func makeSUT(
        seedWorkouts: [Workout] = []
    ) -> (sut: WorkoutsViewModel, workoutStorage: MockWorkoutStorage, exerciseStorage: MockExerciseStorage) {
        let workoutStorage = MockWorkoutStorage()
        let exerciseStorage = MockExerciseStorage()

        workoutStorage.workouts = seedWorkouts
        workoutStorage.currentWorkout = seedWorkouts.first

        // Build an ExportWorkoutUseCase backed by the same mock exercise
        // storage + an in-memory TotalAnalyticsStorage so requestShare
        // never touches the real Factory container during tests.
        let totalAnalytics = MockTotalAnalyticsStorage(
            analyticsStorage: MockAnalyticsStorage(),
            exerciseStorage: exerciseStorage,
            workoutStorage: workoutStorage
        )
        let exportUseCase = ExportWorkoutUseCase(
            exerciseStorage: exerciseStorage,
            totalAnalyticsStorage: totalAnalytics
        )

        let sut = WorkoutsViewModel(
            workoutStorage: workoutStorage,
            exerciseStorage: exerciseStorage,
            deleteWorkoutUseCase: DeleteWorkoutUseCase(
                workoutStorage: workoutStorage,
                exerciseStorage: exerciseStorage
            ),
            duplicateWorkoutUseCase: DuplicateWorkoutUseCase(
                workoutStorage: workoutStorage
            ),
            exportWorkoutUseCase: exportUseCase
        )
        return (sut, workoutStorage, exerciseStorage)
    }

    // MARK: - Initial State

    @Test func workoutsReflectStorage() {
        let seed = Workout(name: "Push", selectedCategories: [.chest])
        let (sut, _, _) = makeSUT(seedWorkouts: [seed])

        #expect(sut.workouts.count == 1)
        #expect(sut.workouts.first?.id == seed.id)
    }

    @Test func currentWorkoutReflectsStorage() {
        let w1 = Workout(name: "A")
        let w2 = Workout(name: "B")
        let (sut, ws, _) = makeSUT(seedWorkouts: [w1, w2])
        ws.currentWorkout = w2

        #expect(sut.currentWorkout?.id == w2.id)
    }

    @Test func defaultWorkoutReflectsStorage() {
        let w = Workout(name: "Default")
        let (sut, ws, _) = makeSUT(seedWorkouts: [w])
        ws.defaultWorkout = w

        #expect(sut.defaultWorkout?.id == w.id)
    }

    // MARK: - createNewWorkout

    @Test func createNewWorkoutAddsWorkoutAndSetsCurrent() {
        let (sut, ws, _) = makeSUT()
        sut.newWorkoutName = "Pull"
        sut.newWorkoutType = .pull
        sut.showingCreateWorkoutFullScreen = true

        sut.createNewWorkout()

        #expect(ws.workouts.count == 1)
        #expect(ws.workouts.first?.name == "Pull")
        // New workouts are not category-restricted — they cover all categories.
        #expect(ws.workouts.first?.selectedCategories == Set(MuscleCategoryGroup.allCases))
        #expect(ws.workouts.first?.type == .pull)
        #expect(ws.currentWorkout?.id == ws.workouts.first?.id)
    }

    @Test func createNewWorkoutResetsFormState() {
        let (sut, _, _) = makeSUT()
        sut.newWorkoutName = "Pull"
        sut.newWorkoutType = .pull
        sut.showingCreateWorkoutFullScreen = true

        sut.createNewWorkout()

        #expect(sut.newWorkoutName.isEmpty)
        #expect(sut.newWorkoutType == nil)
        #expect(sut.showingCreateWorkoutFullScreen == false)
    }

    @Test func createNewWorkoutKeepsFormOpenWhenPersistenceFails() {
        let (sut, workoutStorage, _) = makeSUT()
        workoutStorage.createWorkoutError = StubError.persistenceFailed
        sut.newWorkoutName = "Pull"
        sut.newWorkoutType = .pull
        sut.showingCreateWorkoutFullScreen = true

        sut.createNewWorkout()

        #expect(workoutStorage.workouts.isEmpty)
        #expect(workoutStorage.currentWorkout == nil)
        #expect(sut.showingCreateWorkoutFullScreen)
        #expect(sut.createErrorMessage == "Workout could not be saved.")
        #expect(sut.newWorkoutName == "Pull")
        #expect(sut.newWorkoutType == .pull)
    }

    @Test func createNewWorkoutIgnoresEmptyName() {
        let (sut, ws, _) = makeSUT()
        sut.newWorkoutName = ""

        sut.createNewWorkout()

        #expect(ws.workouts.isEmpty)
    }

    @Test func createNewWorkoutIgnoresMissingType() {
        let (sut, ws, _) = makeSUT()
        sut.newWorkoutName = "Pull"
        sut.newWorkoutType = nil

        sut.createNewWorkout()

        #expect(ws.workouts.isEmpty)
    }

    @Test func createNewWorkoutIgnoresWhitespaceOnlyName() {
        let (sut, ws, _) = makeSUT()
        sut.newWorkoutName = "   \n\t  "

        sut.createNewWorkout()

        #expect(ws.workouts.isEmpty)
    }

    // MARK: - selectWorkout

    @Test func selectWorkoutSetsCurrentWorkout() {
        let w1 = Workout(name: "A")
        let w2 = Workout(name: "B")
        let (sut, ws, _) = makeSUT(seedWorkouts: [w1, w2])

        sut.selectWorkout(w2)

        #expect(ws.currentWorkout?.id == w2.id)
    }

    // MARK: - duplicateWorkout

    @Test func duplicateWorkoutAppendsCopyAndSetsCurrent() {
        let original = Workout(name: "Leg Day", selectedCategories: [.legs])
        let (sut, ws, _) = makeSUT(seedWorkouts: [original])
        sut.showingWorkoutOptions = true

        sut.duplicateWorkout(original)

        #expect(ws.workouts.count == 2)
        #expect(ws.workouts.last?.id != original.id)
        #expect(ws.currentWorkout?.id == ws.workouts.last?.id)
        #expect(sut.showingWorkoutOptions == false)
    }

    // MARK: - deleteWorkout (invariant enforced in VM)

    @Test func deleteWorkoutRemovesFromStorageWhenMultipleExist() {
        let w1 = Workout(name: "A")
        let w2 = Workout(name: "B")
        let (sut, ws, _) = makeSUT(seedWorkouts: [w1, w2])
        sut.showingWorkoutOptions = true

        sut.deleteWorkout(w1)

        #expect(ws.workouts.count == 1)
        #expect(ws.workouts.contains { $0.id == w1.id } == false)
        #expect(sut.showingWorkoutOptions == false)
    }

    /// Regression: the "must keep at least one workout" invariant lives in the VM
    /// (not only in the UI affordance `canDeleteWorkout`).
    @Test func deleteWorkoutIgnoresLastRemainingWorkout() {
        let only = Workout(name: "Only")
        let (sut, ws, _) = makeSUT(seedWorkouts: [only])
        sut.showingWorkoutOptions = true

        sut.deleteWorkout(only)

        #expect(ws.workouts.count == 1)
        #expect(ws.workouts.contains { $0.id == only.id })
        // Guard short-circuits before UI flag is cleared — documenting current behavior.
        #expect(sut.showingWorkoutOptions == true)
    }

    // MARK: - renameWorkout

    @Test func renameWorkoutUpdatesStorageAndClearsState() {
        let original = Workout(name: "Old Name")
        let (sut, ws, _) = makeSUT(seedWorkouts: [original])
        sut.selectedWorkoutForAction = original
        sut.renameWorkoutName = "New Name"
        sut.showingRenameWorkout = true

        sut.renameWorkout()

        #expect(ws.workouts.first?.name == "New Name")
        #expect(sut.renameWorkoutName.isEmpty)
        #expect(sut.showingRenameWorkout == false)
        #expect(sut.selectedWorkoutForAction == nil)
    }

    @Test func renameWorkoutIgnoresEmptyName() {
        let original = Workout(name: "Old Name")
        let (sut, ws, _) = makeSUT(seedWorkouts: [original])
        sut.selectedWorkoutForAction = original
        sut.renameWorkoutName = "   "

        sut.renameWorkout()

        #expect(ws.workouts.first?.name == "Old Name")
    }

    @Test func renameWorkoutIgnoresMissingSelection() {
        let original = Workout(name: "Old Name")
        let (sut, ws, _) = makeSUT(seedWorkouts: [original])
        sut.selectedWorkoutForAction = nil
        sut.renameWorkoutName = "New Name"

        sut.renameWorkout()

        #expect(ws.workouts.first?.name == "Old Name")
    }

    // MARK: - Workout options

    @Test func showWorkoutOptionsSetsSelectionAndOpens() {
        let w = Workout(name: "X")
        let (sut, _, _) = makeSUT(seedWorkouts: [w])

        sut.showWorkoutOptions(for: w)

        #expect(sut.selectedWorkoutForAction?.id == w.id)
        #expect(sut.showingWorkoutOptions == true)
    }

    @Test func hideWorkoutOptionsClearsEverything() {
        let w = Workout(name: "X")
        let (sut, _, _) = makeSUT(seedWorkouts: [w])
        sut.showWorkoutOptions(for: w)
        sut.showDeleteConfirmation()

        sut.hideWorkoutOptions()

        #expect(sut.showingWorkoutOptions == false)
        #expect(sut.showingDeleteConfirmation == false)
        #expect(sut.selectedWorkoutForAction == nil)
    }

    @Test func showWorkoutAnalyticsEntrySetsTargetAndClosesOptions() {
        let workout = Workout(name: "Pull")
        let (sut, _, _) = makeSUT(seedWorkouts: [workout])
        sut.showWorkoutOptions(for: workout)

        sut.showWorkoutAnalyticsEntry(for: workout)

        #expect(sut.workoutForAnalyticsEntry?.id == workout.id)
        #expect(!sut.showingWorkoutOptions)
        #expect(sut.selectedWorkoutForAction == nil)
    }

    @Test func dismissWorkoutAnalyticsEntryClearsTarget() {
        let workout = Workout(name: "Pull")
        let (sut, _, _) = makeSUT(seedWorkouts: [workout])
        sut.showWorkoutAnalyticsEntry(for: workout)

        sut.dismissWorkoutAnalyticsEntry()

        #expect(sut.workoutForAnalyticsEntry == nil)
    }

    // MARK: - showCreateWorkout

    @Test func showCreateWorkoutResetsRequiredFields() {
        let existing = [Workout(name: "W1"), Workout(name: "W2")]
        let (sut, _, _) = makeSUT(seedWorkouts: existing)

        sut.showCreateWorkout()

        #expect(sut.newWorkoutName.isEmpty)
        #expect(sut.newWorkoutType == nil)
        #expect(sut.showingCreateWorkoutFullScreen == true)
    }

    // MARK: - showRenameWorkout

    @Test func showRenameWorkoutPrefillsName() {
        let w = Workout(name: "Original")
        let (sut, _, _) = makeSUT(seedWorkouts: [w])
        sut.showingWorkoutOptions = true

        sut.showRenameWorkout(for: w)

        #expect(sut.selectedWorkoutForAction?.id == w.id)
        #expect(sut.renameWorkoutName == "Original")
        #expect(sut.showingRenameWorkout == true)
        #expect(sut.showingWorkoutOptions == false)
    }

    // MARK: - Delete confirmation flow

    @Test func showDeleteConfirmationSetsFlag() {
        let (sut, _, _) = makeSUT()

        sut.showDeleteConfirmation()

        #expect(sut.showingDeleteConfirmation == true)
    }

    @Test func confirmDeleteDeletesSelectedAndHidesOptions() {
        let w1 = Workout(name: "A")
        let w2 = Workout(name: "B")
        let (sut, ws, _) = makeSUT(seedWorkouts: [w1, w2])
        sut.showWorkoutOptions(for: w1)
        sut.showDeleteConfirmation()

        sut.confirmDelete()

        #expect(ws.workouts.count == 1)
        #expect(ws.workouts.contains { $0.id == w1.id } == false)
        #expect(sut.showingWorkoutOptions == false)
        #expect(sut.showingDeleteConfirmation == false)
        #expect(sut.selectedWorkoutForAction == nil)
    }

    @Test func confirmDeleteWithoutSelectionJustHidesOptions() {
        let w1 = Workout(name: "A")
        let w2 = Workout(name: "B")
        let (sut, ws, _) = makeSUT(seedWorkouts: [w1, w2])
        sut.showingDeleteConfirmation = true

        sut.confirmDelete()

        #expect(ws.workouts.count == 2)
        #expect(sut.showingDeleteConfirmation == false)
    }

    @Test func cancelDeleteResetsConfirmationFlag() {
        let (sut, _, _) = makeSUT()
        sut.showingDeleteConfirmation = true

        sut.cancelDelete()

        #expect(sut.showingDeleteConfirmation == false)
    }

    // MARK: - canDeleteWorkout

    @Test func canDeleteWorkoutFalseWithOneWorkout() {
        let (sut, _, _) = makeSUT(seedWorkouts: [Workout(name: "Only")])
        #expect(sut.canDeleteWorkout == false)
    }

    @Test func canDeleteWorkoutTrueWithMultipleWorkouts() {
        let (sut, _, _) = makeSUT(seedWorkouts: [Workout(name: "A"), Workout(name: "B")])
        #expect(sut.canDeleteWorkout == true)
    }

    // MARK: - Default workout

    @Test func setAsDefaultDelegatesToStorage() {
        let w = Workout(name: "X")
        let (sut, ws, _) = makeSUT(seedWorkouts: [w])

        sut.setAsDefault(w)

        #expect(ws.defaultWorkout?.id == w.id)
    }

    @Test func removeAsDefaultClearsStorage() {
        let w = Workout(name: "X")
        let (sut, ws, _) = makeSUT(seedWorkouts: [w])
        ws.defaultWorkout = w

        sut.removeAsDefault()

        #expect(ws.defaultWorkout == nil)
    }

    @Test func isDefaultWorkoutTrueForDefault() {
        let w = Workout(name: "X")
        let (sut, ws, _) = makeSUT(seedWorkouts: [w])
        ws.defaultWorkout = w

        #expect(sut.isDefaultWorkout(w) == true)
    }

    @Test func isDefaultWorkoutFalseForNonDefault() {
        let w1 = Workout(name: "A")
        let w2 = Workout(name: "B")
        let (sut, ws, _) = makeSUT(seedWorkouts: [w1, w2])
        ws.defaultWorkout = w1

        #expect(sut.isDefaultWorkout(w2) == false)
    }

    // MARK: - Exercise counts

    @Test func exerciseCountsAggregateAcrossCategoriesInOneStorageRead() {
        let w = Workout(name: "X", selectedCategories: Set(MuscleCategoryGroup.allCases))
        let (sut, _, es) = makeSUT(seedWorkouts: [w])

        let armEx = Exercise(name: "Curl", weight: 0, reps: 1, sets: 1, iconName: "defaultArmsIcon", category: .arms)
        let chestEx1 = Exercise(name: "Bench", weight: 0, reps: 1, sets: 1, iconName: "defaultChestIcon", category: .chest)
        let chestEx2 = Exercise(name: "Fly", weight: 0, reps: 1, sets: 1, iconName: "defaultChestIcon", category: .chest)
        es.saveForWorkout([armEx], workoutId: w.id, category: .arms)
        es.saveForWorkout([chestEx1, chestEx2], workoutId: w.id, category: .chest)

        #expect(sut.exerciseCountsByWorkout()[w.id] == 3)
    }

    @Test func exerciseCountsOmitWorkoutsWithoutExercises() {
        let w = Workout(name: "X")
        let (sut, _, _) = makeSUT(seedWorkouts: [w])

        #expect(sut.exerciseCountsByWorkout()[w.id] == nil)
    }

    // MARK: - Export-as-File (Share)

    @Test func requestShare_writesFitnessWorkoutFileToTmpWithSanitizedFilename() throws {
        let workout = Workout(name: "Push/Pull Day?")
        let (sut, _, _) = makeSUT(seedWorkouts: [workout])

        sut.requestShare(for: workout)

        let item = try #require(sut.workoutToShare)
        let url = try #require(item.fileURL)
        // Custom extension exclusively owned by FitnessApp (no clash with
        // public.json owners on iOS 17+).
        #expect(url.pathExtension == "fitnessworkout")
        // Special chars get replaced with `_`; the name itself must NOT contain `/` or `?`
        #expect(!url.lastPathComponent.contains("/"))
        #expect(!url.lastPathComponent.contains("?"))
        #expect(FileManager.default.fileExists(atPath: url.path))
        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }

    @Test func requestShare_fileContentMatchesJSON() throws {
        let workout = Workout(name: "Roundtrip")
        let (sut, _, _) = makeSUT(seedWorkouts: [workout])

        sut.requestShare(for: workout)

        let item = try #require(sut.workoutToShare)
        let url = try #require(item.fileURL)
        defer { try? FileManager.default.removeItem(at: url) }
        let onDisk = try String(contentsOf: url, encoding: .utf8)
        #expect(onDisk == item.json, "File on disk must match the in-memory JSON string.")
    }

    @Test func sanitizeFilename_replacesUnsafeChars() {
        #expect(WorkoutShareFileWriter.sanitizeFilename("Push/Pull") == "Push_Pull")
        #expect(WorkoutShareFileWriter.sanitizeFilename("A:B?C*D") == "A_B_C_D")
        #expect(WorkoutShareFileWriter.sanitizeFilename("Normal Workout") == "Normal Workout")
        #expect(WorkoutShareFileWriter.sanitizeFilename("   ") == "workout", "Whitespace-only collapses to fallback.")
        #expect(WorkoutShareFileWriter.sanitizeFilename("???") == "workout", "All-unsafe collapses through the underscore-only guard to fallback.")
        #expect(WorkoutShareFileWriter.sanitizeFilename("Push//Pull") == "Push_Pull", "Consecutive unsafe chars collapse to a single underscore.")
        #expect(WorkoutShareFileWriter.sanitizeFilename("") == "workout", "Empty input uses the literal fallback.")
    }
}
