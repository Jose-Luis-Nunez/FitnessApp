import Testing
import FitnessCore
@testable import FitnessTraining
import FitnessTestSupport

@Suite("ExerciseWeightProgressionUseCase", .tags(.fast))
struct ExerciseWeightProgressionUseCaseTests {
    private let sut = ExerciseWeightProgressionUseCase()

    @Test func raisesWeightAndSetsRepsToTwelveWhenEverySetQualifies() {
        let exercise = makeExercise(weight: 20, reps: 8, sets: 3)

        let result = sut.execute(
            exercise: exercise,
            setProgress: [
                completedSet(reps: 12, weight: 21),
                completedSet(reps: 15, weight: 21),
                completedSet(reps: 12, weight: 21)
            ]
        )

        #expect(result.weight == 21)
        #expect(result.reps == 12)
        #expect(result.sets == 3)
    }

    @Test func usesLowestWeightWhenEverySetUsesAHigherWeight() {
        let exercise = makeExercise(weight: 20, reps: 10, sets: 3)

        let result = sut.execute(
            exercise: exercise,
            setProgress: [
                completedSet(reps: 12, weight: 21),
                completedSet(reps: 12, weight: 22),
                completedSet(reps: 12, weight: 23)
            ]
        )

        #expect(result.weight == 21)
        #expect(result.reps == 12)
        #expect(result.sets == 3)
    }

    @Test func keepsIdleValuesWhenAnySetFallsBelowTwelveReps() {
        let exercise = makeExercise(weight: 20, reps: 10, sets: 3)

        let result = sut.execute(
            exercise: exercise,
            setProgress: [
                completedSet(reps: 12, weight: 21),
                completedSet(reps: 8, weight: 21),
                completedSet(reps: 12, weight: 21)
            ]
        )

        #expect(result.weight == 20)
        #expect(result.reps == 10)
        #expect(result.sets == 3)
    }

    @Test func keepsIdleValuesWhenFewerThanConfiguredSetsAreCompleted() {
        let exercise = makeExercise(weight: 20, reps: 10, sets: 3)

        let result = sut.execute(
            exercise: exercise,
            setProgress: [
                completedSet(reps: 12, weight: 21),
                completedSet(reps: 12, weight: 21)
            ]
        )

        assertIdleValuesAreUnchanged(result, from: exercise)
    }

    @Test func keepsIdleValuesWhenAConfiguredSetIsNotCompleted() {
        let exercise = makeExercise(weight: 20, reps: 10, sets: 3)

        let result = sut.execute(
            exercise: exercise,
            setProgress: [
                completedSet(reps: 12, weight: 21),
                completedSet(reps: 12, weight: 21),
                SetProgress(status: .notStarted, currentReps: 12, weight: 21)
            ]
        )

        assertIdleValuesAreUnchanged(result, from: exercise)
    }

    @Test(arguments: [20.0, 18.0])
    func keepsIdleValuesWhenWeightIsNotHigher(_ trainedWeight: Double) {
        let exercise = makeExercise(weight: 20, reps: 10, sets: 3)

        let result = sut.execute(
            exercise: exercise,
            setProgress: Array(repeating: completedSet(reps: 12, weight: trainedWeight), count: 3)
        )

        assertIdleValuesAreUnchanged(result, from: exercise)
    }

    @Test func acceptsMoreCompletedSetsThanConfigured() {
        let exercise = makeExercise(weight: 20, reps: 10, sets: 3)

        let result = sut.execute(
            exercise: exercise,
            setProgress: Array(repeating: completedSet(reps: 12, weight: 21), count: 4)
        )

        #expect(result.weight == 21)
        #expect(result.reps == 12)
        #expect(result.sets == 3)
    }

    private func makeExercise(weight: Double, reps: Int, sets: Int) -> Exercise {
        FitnessTestSupport.makeExercise(
            name: "Curl",
            weight: weight,
            reps: reps,
            sets: sets,
            category: .arms
        )
    }

    private func completedSet(reps: Int, weight: Double) -> SetProgress {
        SetProgress(status: .completedMore, currentReps: reps, weight: weight)
    }

    private func assertIdleValuesAreUnchanged(_ result: Exercise, from exercise: Exercise) {
        #expect(result.weight == exercise.weight)
        #expect(result.reps == exercise.reps)
        #expect(result.sets == exercise.sets)
    }
}
