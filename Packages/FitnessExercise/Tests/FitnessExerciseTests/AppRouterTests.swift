import Testing
import FitnessTestSupport
@testable import FitnessExercise

@Suite("AppRouter", .tags(.fast))
@MainActor
struct AppRouterTests {

    // MARK: - Scene mapping

    @Test
    func initialScene_isWorkouts() {
        let router = AppRouter()
        #expect(router.currentScene == .workouts)
    }

    @Test
    func navigateToHome_setsHomeScene() {
        let router = AppRouter()
        router.navigate(to: .home)
        #expect(router.currentScene == .home)
    }

    @Test
    func navigateToHome_marksItAsPushedFromWorkoutList() {
        let router = AppRouter()
        router.navigate(to: .home)

        #expect(router.isHomePushedFromWorkoutList)
    }

    @Test
    func replaceAllWithHome_keepsItAsRoot() {
        let router = AppRouter()
        router.replaceAll(with: [.home])

        #expect(!router.isHomePushedFromWorkoutList)
    }

    @Test
    func switchToAnalytics_setsAnalyticsScene() {
        let router = AppRouter()
        router.switchToAnalytics()
        #expect(router.currentScene == .analytics)
    }

    @Test
    func switchToSchedule_setsScheduleScene() {
        let router = AppRouter()
        router.switchToSchedule()
        #expect(router.currentScene == .schedule)
    }

    @Test
    func switchToProfile_setsProfileScene() {
        let router = AppRouter()
        router.switchToProfile()
        #expect(router.currentScene == .profile)
    }

    @Test
    func navigateToMuscleCategory_setsCategoryScene() {
        let router = AppRouter()
        router.navigate(to: .muscleCategory(.arms))
        #expect(router.currentScene == .category)
    }

    // MARK: - Navigation stack

    @Test
    func popToRoot_clearsStackAndResetsToWorkouts() {
        let router = AppRouter()
        router.switchToAnalytics()
        #expect(router.currentScene == .analytics)

        router.popToRoot()
        #expect(router.currentScene == .workouts)
        #expect(router.isEmpty)
    }

    @Test
    func pop_removesLastDestination() {
        let router = AppRouter()
        router.navigate(to: .home)
        router.navigate(to: .muscleCategory(.arms))
        #expect(router.currentScene == .category)

        router.pop()
        #expect(router.currentScene == .home)
    }

    @Test
    func pop_restoresHomeNavigationOrigin() {
        let router = AppRouter()
        router.navigate(to: .home)
        router.navigate(to: .muscleCategory(.arms))

        router.pop()

        #expect(router.isHomePushedFromWorkoutList)
    }

    @Test
    func switchToAnalytics_replacesEntireStack() {
        let router = AppRouter()
        router.navigate(to: .home)
        router.navigate(to: .muscleCategory(.arms))

        router.switchToAnalytics()
        #expect(router.currentScene == .analytics)
        #expect(router.path.count == 1)
    }

    @Test
    func isEmpty_trueAtRoot() {
        let router = AppRouter()
        #expect(router.isEmpty)
    }

    @Test
    func isEmpty_falseAfterNavigate() {
        let router = AppRouter()
        router.navigate(to: .home)
        #expect(!router.isEmpty)
    }

    // MARK: - Analytics is distinct from home

    @Test
    func analyticsScene_isDistinctFromHomeScene() {
        let router = AppRouter()
        router.switchToAnalytics()
        #expect(router.currentScene == .analytics)
        #expect(router.currentScene != .home)
    }
}
