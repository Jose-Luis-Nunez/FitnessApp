import SwiftUI

public enum AppCurrentScene: Sendable {
    case workouts, home, profile, category, training, schedule
}

public final class AppRouter: ObservableObject {
    @Published public var path = NavigationPath() {
        didSet { reconcileDestinations() }
    }
    @Published private(set) public var currentScene: AppCurrentScene = .workouts

    private var destinations: [NavigationDestination] = []
    private var isMutating = false

    public init() {}

    public func navigate(to destination: NavigationDestination) {
        isMutating = true
        destinations.append(destination)
        path.append(destination)
        isMutating = false
        updateScene()
    }

    public func pop() {
        guard !destinations.isEmpty else { return }
        isMutating = true
        destinations.removeLast()
        path.removeLast()
        isMutating = false
        updateScene()
    }

    public func popToRoot() {
        isMutating = true
        destinations.removeAll()
        path = NavigationPath()
        isMutating = false
        updateScene()
    }

    public func replaceAll(with newDestinations: [NavigationDestination]) {
        isMutating = true
        destinations = newDestinations
        var newPath = NavigationPath()
        for dest in newDestinations { newPath.append(dest) }
        path = newPath
        isMutating = false
        updateScene()
    }

    public func switchToAnalytics() { switchTo(.totalAnalytics) }
    public func switchToSchedule() { switchTo(.schedule) }
    public func switchToProfile() { switchTo(.profile) }

    public var isEmpty: Bool { path.isEmpty }

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
