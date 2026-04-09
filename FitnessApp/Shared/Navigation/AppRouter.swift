import SwiftUI

enum AppCurrentScene { case workouts, home, profile, category, training, schedule }

final class AppRouter: ObservableObject {
    @Published var path = NavigationPath() {
        didSet { reconcileDestinations() }
    }
    @Published private(set) var currentScene: AppCurrentScene = .workouts

    private var destinations: [NavigationDestination] = []
    private var isMutating = false

    // MARK: - Push

    func navigate(to destination: NavigationDestination) {
        isMutating = true
        destinations.append(destination)
        path.append(destination)
        isMutating = false
        updateScene()
    }

    // MARK: - Pop

    func pop() {
        guard !destinations.isEmpty else { return }
        isMutating = true
        destinations.removeLast()
        path.removeLast()
        isMutating = false
        updateScene()
    }

    func popToRoot() {
        isMutating = true
        destinations.removeAll()
        path = NavigationPath()
        isMutating = false
        updateScene()
    }

    // MARK: - Replace

    func replaceAll(with newDestinations: [NavigationDestination]) {
        isMutating = true
        destinations = newDestinations
        var newPath = NavigationPath()
        for dest in newDestinations { newPath.append(dest) }
        path = newPath
        isMutating = false
        updateScene()
    }

    // MARK: - Tab Convenience

    func switchToAnalytics() { switchTo(.totalAnalytics) }
    func switchToSchedule() { switchTo(.schedule) }
    func switchToProfile() { switchTo(.profile) }

    // MARK: - State

    var isEmpty: Bool { path.isEmpty }

    // MARK: - Private

    private func switchTo(_ destination: NavigationDestination) {
        isMutating = true
        destinations = [destination]
        var newPath = NavigationPath()
        newPath.append(destination)
        path = newPath
        isMutating = false
        updateScene()
    }

    private func reconcileDestinations() {
        guard !isMutating else { return }
        while destinations.count > path.count {
            destinations.removeLast()
        }
        updateScene()
    }

    private func updateScene() {
        guard let last = destinations.last else {
            currentScene = .workouts
            return
        }
        switch last {
        case .home:               currentScene = .home
        case .profile:            currentScene = .profile
        case .totalAnalytics:     currentScene = .home
        case .schedule:           currentScene = .schedule
        case .muscleCategory:     currentScene = .category
        case .training:           currentScene = .training
        }
    }
}
