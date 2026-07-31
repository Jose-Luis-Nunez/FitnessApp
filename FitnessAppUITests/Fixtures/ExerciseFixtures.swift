extension TestExerciseFixture {
    static let defaultArmsExercise = TestExerciseFixture(
        name: "Bicep Curl",
        weight: 15.0,
        reps: 10,
        sets: 3,
        noSeats: true,
        icon: "dumbbell",
        category: "arms",
        bilateral: false,
        completed: false
    )

    static let bilateralTorsoExercise = TestExerciseFixture(
        name: "Torso Rotation",
        weight: 20,
        reps: 12,
        sets: 3,
        noSeats: true,
        icon: "dumbbell",
        category: "abs",
        bilateral: true,
        completed: false
    )
}
