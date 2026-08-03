struct TestExerciseFixture {
    let name: String
    let weight: Double
    let reps: Int
    let sets: Int
    let noSeats: Bool
    let icon: String
    let category: String
    let bilateral: Bool
    let completed: Bool

    func with(
        name: String? = nil, weight: Double? = nil,
        reps: Int? = nil, sets: Int? = nil,
        noSeats: Bool? = nil, icon: String? = nil,
        category: String? = nil,
        bilateral: Bool? = nil,
        completed: Bool? = nil
    ) -> TestExerciseFixture {
        TestExerciseFixture(
            name: name ?? self.name,
            weight: weight ?? self.weight,
            reps: reps ?? self.reps,
            sets: sets ?? self.sets,
            noSeats: noSeats ?? self.noSeats,
            icon: icon ?? self.icon,
            category: category ?? self.category,
            bilateral: bilateral ?? self.bilateral,
            completed: completed ?? self.completed
        )
    }

    var launchConfig: UITestExerciseConfig {
        UITestExerciseConfig(
            category: category,
            exerciseName: name,
            weight: weight,
            reps: reps,
            sets: sets,
            noSeats: noSeats,
            icon: icon,
            executionMode: bilateral ? "bilateral" : "standard",
            isCompleted: completed
        )
    }
}

// MARK: - UITestLaunchConfig factory for exercise fixtures

extension UITestLaunchConfig {
    static func exerciseList(
        _ fixture: TestExerciseFixture,
        additional: [TestExerciseFixture] = []
    ) -> UITestLaunchConfig {
        fixtureConfig(screen: .home, fixture: fixture, additional: additional)
    }

    static func exerciseCategory(
        _ fixture: TestExerciseFixture,
        additional: [TestExerciseFixture] = [],
        seedAnalyticsHistory: Bool = false
    ) -> UITestLaunchConfig {
        fixtureConfig(
            screen: .category,
            fixture: fixture,
            additional: additional,
            seedAnalyticsHistory: seedAnalyticsHistory
        )
    }

    private static func fixtureConfig(
        screen: UITestScreen,
        fixture: TestExerciseFixture,
        additional: [TestExerciseFixture],
        seedAnalyticsHistory: Bool = false
    ) -> UITestLaunchConfig {
        UITestLaunchConfig(
            screen: screen,
            category: fixture.category,
            exerciseName: fixture.name,
            weight: fixture.weight,
            reps: fixture.reps,
            sets: fixture.sets,
            noSeats: fixture.noSeats,
            icon: fixture.icon,
            executionMode: fixture.bilateral ? "bilateral" : "standard",
            isCompleted: fixture.completed,
            additionalExercises: additional.map(\.launchConfig),
            seedAnalyticsHistory: seedAnalyticsHistory
        )
    }
}
