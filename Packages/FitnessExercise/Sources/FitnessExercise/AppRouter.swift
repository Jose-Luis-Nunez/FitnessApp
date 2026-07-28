import SwiftUI
import Observation

public enum AppCurrentScene: Sendable {
    case workouts, home, profile, category, training, schedule, analytics
}

@Observable
@MainActor
public final class AppRouter {
    public var path = NavigationPath() {
        didSet { reconcileDestinations() }
    }
    public private(set) var currentScene: AppCurrentScene = .workouts

    private var destinations: [NavigationDestination] = []
    /// Tracks whether each destination was pushed from the preceding screen.
    /// In particular, `.home` can be entered either from the Workouts list
    /// (back-navigation allowed) or as the Training tab's replacement root.
    private var wasPushed: [Bool] = []
    private var isMutating = false

    public init() {}

    public func navigate(to destination: NavigationDestination) {
        isMutating = true
        destinations.append(destination)
        wasPushed.append(true)
        path.append(destination)
        isMutating = false
        updateScene()
    }

    public func pop() {
        guard !destinations.isEmpty else { return }
        isMutating = true
        destinations.removeLast()
        wasPushed.removeLast()
        path.removeLast()
        isMutating = false
        updateScene()
    }

    public func popToRoot() {
        isMutating = true
        destinations.removeAll()
        wasPushed.removeAll()
        path = NavigationPath()
        isMutating = false
        updateScene()
    }

    public func replaceAll(with newDestinations: [NavigationDestination]) {
        isMutating = true
        destinations = newDestinations
        wasPushed = Array(repeating: false, count: newDestinations.count)
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

    /// Only a workout opened from the list may return to that list. A `.home`
    /// destination installed by a tab switch or launch strategy is a root.
    public var isHomePushedFromWorkoutList: Bool {
        guard destinations.last == .home else { return false }
        return wasPushed.last ?? false
    }

    private func switchTo(_ destination: NavigationDestination) {
        isMutating = true
        destinations = [destination]
        wasPushed = [false]
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
            wasPushed.removeLast()
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
        case .totalAnalytics:     currentScene = .analytics
        case .schedule:           currentScene = .schedule
        case .muscleCategory:     currentScene = .category
        case .training:           currentScene = .training
        }
    }
}
