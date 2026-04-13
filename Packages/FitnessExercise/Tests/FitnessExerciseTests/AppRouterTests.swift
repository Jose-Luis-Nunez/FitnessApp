import Testing
@testable import FitnessExercise

@Suite("AppRouter")
struct AppRouterTests {

    // MARK: - Scene mapping

    @Test @MainActor
    func initialScene_isWorkouts() {
        let router = AppRouter()
        #expect(router.currentScene == .workouts)
    }

    @Test @MainActor
    func navigateToHome_setsHomeScene() {
        let router = AppRouter()
        router.navigate(to: .home)
        #expect(router.currentScene == .home)
    }

    @Test @MainActor
    func switchToAnalytics_setsAnalyticsScene() {
        let router = AppRouter()
        router.switchToAnalytics()
        #expect(router.currentScene == .analytics)
    }

    @Test @MainActor
    func switchToSchedule_setsScheduleScene() {
        let router = AppRouter()
        router.switchToSchedule()
        #expect(router.currentScene == .schedule)
    }

    @Test @MainActor
    func switchToProfile_setsProfileScene() {
        let router = AppRouter()
        router.switchToProfile()
        #expect(router.currentScene == .profile)
    }

    @Test @MainActor
    func navigateToMuscleCategory_setsCategoryScene() {
        let router = AppRouter()
        router.navigate(to: .muscleCategory(.arms))
        #expect(router.currentScene == .category)
    }

    // MARK: - Navigation stack

    @Test @MainActor
    func popToRoot_clearsStackAndResetsToWorkouts() {
        let router = AppRouter()
        router.switchToAnalytics()
        #expect(router.currentScene == .analytics)

        router.popToRoot()
        #expect(router.currentScene == .workouts)
        #expect(router.isEmpty)
    }

    @Test @MainActor
    func pop_removesLastDestination() {
        let router = AppRouter()
        router.navigate(to: .home)
        router.navigate(to: .muscleCategory(.arms))
        #expect(router.currentScene == .category)

        router.pop()
        #expect(router.currentScene == .home)
    }

    @Test @MainActor
    func switchToAnalytics_replacesEntireStack() {
        let router = AppRouter()
        router.navigate(to: .home)
        router.navigate(to: .muscleCategory(.arms))

        router.switchToAnalytics()
        #expect(router.currentScene == .analytics)
        #expect(router.path.count == 1)
    }

    @Test @MainActor
    func isEmpty_trueAtRoot() {
        let router = AppRouter()
        #expect(router.isEmpty)
    }

    @Test @MainActor
    func isEmpty_falseAfterNavigate() {
        let router = AppRouter()
        router.navigate(to: .home)
        #expect(!router.isEmpty)
    }

    // MARK: - Analytics is distinct from home

    @Test @MainActor
    func analyticsScene_isDistinctFromHomeScene() {
        let router = AppRouter()
        router.switchToAnalytics()
        #expect(router.currentScene == .analytics)
        #expect(router.currentScene != .home)
    }
}
