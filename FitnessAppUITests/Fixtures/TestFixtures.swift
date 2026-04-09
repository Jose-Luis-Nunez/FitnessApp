struct TestExerciseFixture {
    let name: String
    let weight: Double
    let reps: Int
    let sets: Int
    let noSeats: Bool
    let icon: String
    let category: String

    func with(
        name: String? = nil, weight: Double? = nil,
        reps: Int? = nil, sets: Int? = nil,
        noSeats: Bool? = nil, icon: String? = nil,
        category: String? = nil
    ) -> TestExerciseFixture {
        TestExerciseFixture(
            name: name ?? self.name,
            weight: weight ?? self.weight,
            reps: reps ?? self.reps,
            sets: sets ?? self.sets,
            noSeats: noSeats ?? self.noSeats,
            icon: icon ?? self.icon,
            category: category ?? self.category
        )
    }
}

// MARK: - UITestLaunchConfig factory for exercise fixtures

extension UITestLaunchConfig {
    static func training(_ fixture: TestExerciseFixture) -> UITestLaunchConfig {
        UITestLaunchConfig(
            screen: .training,
            category: fixture.category,
            exerciseName: fixture.name,
            weight: fixture.weight,
            reps: fixture.reps,
            sets: fixture.sets,
            noSeats: fixture.noSeats,
            icon: fixture.icon
        )
    }
}
