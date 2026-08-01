import FitnessCore
import FitnessTestSupport
import Foundation
import Testing
@testable import FitnessAnalytics

@Suite("WorkoutAnalyticsEntryViewModel", .tags(.fast))
@MainActor
struct WorkoutAnalyticsEntryViewModelTests {
    @Test func loadsOnlyActiveExercisesAndSelectsThem() {
        let workout = Workout(name: "Pull")
        let active = makeExercise(name: "Curl", category: .arms)
        let inactive = makeExercise(
            name: "Old Curl",
            category: .arms,
            isActive: false
        )
        let back = makeExercise(name: "Row", category: .back)
        let (sut, _) = makeSUT(
            workout: workout,
            exercises: [.arms: [active, inactive], .back: [back]]
        )

        #expect(sut.drafts.map(\.id) == [active.id, back.id])
        #expect(sut.drafts.allSatisfy { $0.isSelected })
        #expect(sut.selectedCount == 2)
    }

    @Test func emptyAndDeselectedDraftsCannotSave() {
        let emptyWorkout = Workout(name: "Empty")
        let (empty, _) = makeSUT(workout: emptyWorkout, exercises: [:])
        #expect(!empty.canSave)

        let workout = Workout(name: "Pull")
        let exercise = makeExercise()
        let (deselected, _) = makeSUT(
            workout: workout,
            exercises: [.arms: [exercise]]
        )
        deselected.toggleSelection(for: exercise.id)
        #expect(!deselected.canSave)
    }

    @Test func invalidEditedDraftCannotSave() {
        let workout = Workout(name: "Pull")
        let exercise = makeExercise()
        let (sut, _) = makeSUT(
            workout: workout,
            exercises: [.arms: [exercise]]
        )
        let invalid = AnalyticsEntry(
            exerciseId: exercise.id,
            date: .now,
            setProgress: [
                SetProgress(
                    status: .completedDone,
                    currentReps: 0,
                    weight: exercise.weight,
                    logicalSetIndex: 0
                ),
            ]
        )

        sut.updateDraft(exerciseId: exercise.id, with: invalid)

        #expect(!sut.canSave)
        #expect(!sut.save())
    }

    @Test func createsEveryConfiguredStandardSet() throws {
        let workout = Workout(name: "Push")
        let exercise = makeExercise(weight: 60, reps: 10, sets: 3)
        let (sut, _) = makeSUT(
            workout: workout,
            exercises: [.arms: [exercise]]
        )

        let draft = try #require(sut.draft(for: exercise.id))
        #expect(draft.entry.setProgress.count == 3)
        #expect(draft.entry.setProgress.map(\.currentReps) == [10, 10, 10])
        #expect(draft.entry.setProgress.map(\.weight) == [60, 60, 60])
        #expect(draft.entry.setProgress.map(\.logicalSetIndex) == [0, 1, 2])
    }

    @Test func countsAppendedStandardSetWithoutLogicalIndex() throws {
        let workout = Workout(name: "Push")
        let exercise = makeExercise(weight: 60, reps: 10, sets: 1)
        let (sut, _) = makeSUT(
            workout: workout,
            exercises: [.arms: [exercise]]
        )
        let original = try #require(sut.draft(for: exercise.id)?.entry)
        let edited = AnalyticsEntry(
            id: original.id,
            exerciseId: original.exerciseId,
            date: original.date,
            setProgress: original.setProgress + [
                SetProgress(
                    status: .completedDone,
                    currentReps: 8,
                    weight: 55
                ),
            ]
        )

        sut.updateDraft(exerciseId: exercise.id, with: edited)

        #expect(sut.draft(for: exercise.id)?.setCount == 2)
    }

    @Test func createsCompleteBilateralPairs() throws {
        let workout = Workout(name: "Core")
        let exercise = makeExercise(
            weight: 20,
            reps: 12,
            sets: 2,
            category: .abs,
            executionMode: .bilateral
        )
        let (sut, _) = makeSUT(
            workout: workout,
            exercises: [.abs: [exercise]]
        )

        let progress = try #require(sut.draft(for: exercise.id)?.entry.setProgress)
        #expect(progress.map(\.side) == [.left, .right, .left, .right])
        #expect(progress.map(\.logicalSetIndex) == [0, 0, 1, 1])
        #expect(sut.draft(for: exercise.id)?.setCount == 2)
    }

    @Test func bodyweightDraftWithZeroWeightCanSave() {
        let workout = Workout(name: "Bodyweight")
        let exercise = makeExercise(weight: 0, reps: 12, sets: 2)
        let (sut, _) = makeSUT(
            workout: workout,
            exercises: [.arms: [exercise]]
        )

        #expect(sut.canSave)
    }

    @Test func accessibilityDescribesWeightedDraft() throws {
        let workout = Workout(name: "Push")
        let exercise = makeExercise(weight: 60, reps: 10, sets: 3)
        let (sut, _) = makeSUT(
            workout: workout,
            exercises: [.arms: [exercise]]
        )
        let draft = try #require(sut.draft(for: exercise.id))

        #expect(
            WorkoutAnalyticsAccessibility.value(for: draft)
                == "Arms, 60 kilograms, 3 sets, 10 reps"
        )
    }

    @Test func accessibilityOmitsWeightForBodyweightDraft() throws {
        let workout = Workout(name: "Bodyweight")
        let exercise = makeExercise(weight: 0, reps: 12, sets: 2)
        let (sut, _) = makeSUT(
            workout: workout,
            exercises: [.arms: [exercise]]
        )
        let draft = try #require(sut.draft(for: exercise.id))

        #expect(
            WorkoutAnalyticsAccessibility.value(for: draft)
                == "Arms, 2 sets, 12 reps"
        )
    }

    @Test func accessibilityDescribesVariableDraftValues() {
        let exercise = makeExercise(weight: 60, reps: 10, sets: 2)
        let draft = WorkoutAnalyticsExerciseDraft(
            exercise: exercise,
            isSelected: true,
            entry: AnalyticsEntry(
                exerciseId: exercise.id,
                date: .now,
                setProgress: [
                    SetProgress(
                        status: .completedDone,
                        currentReps: 10,
                        weight: 60
                    ),
                    SetProgress(
                        status: .completedDone,
                        currentReps: 8,
                        weight: 55
                    ),
                ]
            )
        )

        #expect(
            WorkoutAnalyticsAccessibility.value(for: draft)
                == "Arms, Variable weight, 2 sets, Variable reps"
        )
    }

    @Test func savesEditedValuesWithoutMutatingExerciseConfiguration() throws {
        let workout = Workout(name: "Push")
        let exercise = makeExercise(weight: 60, reps: 10, sets: 1)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let (sut, analytics) = makeSUT(
            workout: workout,
            selectedDate: date,
            exercises: [.arms: [exercise]]
        )
        let edited = AnalyticsEntry(
            exerciseId: exercise.id,
            date: date,
            setProgress: [
                SetProgress(
                    status: .completedDone,
                    currentReps: 8,
                    weight: 55,
                    logicalSetIndex: 0
                ),
            ]
        )

        sut.updateDraft(exerciseId: exercise.id, with: edited)
        #expect(sut.save())

        let saved = try #require(analytics.load(for: exercise.id).first)
        #expect(saved.date == date)
        #expect(saved.setProgress[0].currentReps == 8)
        #expect(saved.setProgress[0].weight == 55)
        #expect(sut.draft(for: exercise.id)?.exercise.weight == 60)
        #expect(sut.draft(for: exercise.id)?.exercise.reps == 10)
    }

    @Test func preservesSameDayHistoryAndAppendsOneEntryPerSelectedExercise() {
        let workout = Workout(name: "Full")
        let first = makeExercise(name: "Curl", category: .arms)
        let second = makeExercise(name: "Row", category: .back)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let (sut, analytics) = makeSUT(
            workout: workout,
            selectedDate: date,
            exercises: [.arms: [first], .back: [second]]
        )
        analytics.save(
            [makeEntry(exerciseId: first.id, date: date, reps: 7)],
            for: first.id
        )

        #expect(sut.save())

        #expect(analytics.load(for: first.id).count == 2)
        #expect(analytics.load(for: second.id).count == 1)
    }

    @Test func excludesDeselectedExercisesFromSave() {
        let workout = Workout(name: "Pull")
        let first = makeExercise(name: "Curl", category: .arms)
        let second = makeExercise(name: "Row", category: .back)
        let (sut, analytics) = makeSUT(
            workout: workout,
            exercises: [.arms: [first], .back: [second]]
        )

        sut.toggleSelection(for: second.id)
        #expect(sut.save())

        #expect(analytics.load(for: first.id).count == 1)
        #expect(analytics.load(for: second.id).isEmpty)
    }

    @Test func saveIsTerminalAndCannotAppendTwice() {
        let workout = Workout(name: "Pull")
        let exercise = makeExercise()
        let (sut, analytics) = makeSUT(
            workout: workout,
            exercises: [.arms: [exercise]]
        )

        #expect(sut.save())
        #expect(!sut.save())

        #expect(sut.saveState == .saved)
        #expect(analytics.load(for: exercise.id).count == 1)
    }

    @Test func storageFailureDoesNotDismissOrEnterSavedState() {
        let workout = Workout(name: "Pull")
        let exercise = makeExercise()
        let (sut, analytics) = makeSUT(
            workout: workout,
            exercises: [.arms: [exercise]]
        )
        analytics.saveSucceeds = false

        #expect(!sut.save())
        #expect(sut.saveState == .editing)
        #expect(sut.saveErrorMessage != nil)
        #expect(analytics.load(for: exercise.id).isEmpty)
    }

    private func makeSUT(
        workout: Workout,
        selectedDate: Date = .now,
        exercises: [MuscleCategoryGroup: [Exercise]]
    ) -> (WorkoutAnalyticsEntryViewModel, MockAnalyticsStorage) {
        let exerciseStorage = MockExerciseStorage()
        exerciseStorage.exercisesByCategory = exercises
        let analytics = MockAnalyticsStorage()
        let saveUseCase = SaveWorkoutAnalyticsUseCase(
            batchStorage: analytics
        )
        let sut = WorkoutAnalyticsEntryViewModel(
            workout: workout,
            selectedDate: selectedDate,
            exerciseStorage: exerciseStorage,
            saveUseCase: saveUseCase
        )
        return (sut, analytics)
    }

    private func makeEntry(
        exerciseId: UUID,
        date: Date,
        reps: Int
    ) -> AnalyticsEntry {
        AnalyticsEntry(
            exerciseId: exerciseId,
            date: date,
            setProgress: [
                SetProgress(
                    status: .completedDone,
                    currentReps: reps,
                    weight: 20
                ),
            ]
        )
    }
}
