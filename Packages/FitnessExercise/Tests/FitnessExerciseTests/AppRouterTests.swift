import Foundation
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

    @Test
    func presentTraining_keepsCurrentSceneAndNavigationPath() {
        let router = AppRouter()
        router.replaceAll(with: [.home, .muscleCategory(.arms)])
        let pathCount = router.path.count
        let exerciseId = UUID()

        router.presentTraining(exerciseId: exerciseId, category: .arms)

        #expect(router.currentScene == .category)
        #expect(router.path.count == pathCount)
        #expect(router.trainingPresentation?.exerciseId == exerciseId)
        #expect(router.trainingPresentation?.category == .arms)
    }

    @Test
    func dismissTraining_keepsParentNavigationState() {
        let router = AppRouter()
        router.replaceAll(with: [.home])
        router.presentTraining(exerciseId: UUID(), category: .arms)

        router.dismissTraining()

        #expect(router.trainingPresentation == nil)
        #expect(router.currentScene == .home)
        #expect(router.path.count == 1)
        #expect(!router.isHomePushedFromWorkoutList)
    }

    @Test
    func navigationMutationsDismissTrainingPresentation() {
        let mutations: [(AppRouter) -> Void] = [
            { $0.navigate(to: .muscleCategory(.arms)) },
            { $0.pop() },
            { $0.popToRoot() },
            { $0.replaceAll(with: [.home]) },
            { $0.switchToProfile() },
        ]

        for mutate in mutations {
            let router = AppRouter()
            router.navigate(to: .home)
            router.presentTraining(exerciseId: UUID(), category: .arms)

            mutate(router)

            #expect(router.trainingPresentation == nil)
        }
    }

    @Test
    func navigationStackBindingMutationDismissesTrainingPresentation() {
        let router = AppRouter()
        router.navigate(to: .home)
        router.navigate(to: .muscleCategory(.arms))
        router.presentTraining(exerciseId: UUID(), category: .arms)

        router.path.removeLast()

        #expect(router.trainingPresentation == nil)
        #expect(router.currentScene == .home)
        #expect(router.path.count == 1)
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
