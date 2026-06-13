import Foundation
import Observation
import UIKit
import FitnessCore
import FitnessStorage
import FitnessWorkouts
import Factory

/// State and business logic for the Friends section in the Profile screen.
@Observable
@MainActor
public final class FriendsViewModel {
    // MARK: - Section state
    public var isExpanded = false

    // MARK: - Friend selection
    public var selectedFriendId: UUID?

    public var friends: [Friend] { friendStorage.friends }

    public var selectedFriend: Friend? {
        guard let id = selectedFriendId else { return nil }
        return friends.first { $0.id == id }
    }

    // MARK: - Sheet flags
    public var showingAddFriend = false
    public var showingExportPicker = false
    public var workoutToShare: WorkoutShareItem?
    public var exportErrorMessage: String?
    public var pendingFriendJSON: String?
    public var pendingFriendFileName: String?

    // MARK: - Comparison
    public private(set) var comparison: FriendComparison?
    public private(set) var comparisonError: String?

    // MARK: - Dependencies
    @ObservationIgnored private let friendStorage: FriendStoring
    @ObservationIgnored private let workoutStorage: WorkoutStoring
    @ObservationIgnored private let exerciseStorage: ExerciseStoring
    @ObservationIgnored private let exportWorkoutUseCase: ExportWorkoutUseCase
    @ObservationIgnored private let loadFriendComparisonUseCase: LoadFriendComparisonUseCase
    /// In-flight comparison load. Cancelled before a new load starts so a slow
    /// earlier load can never land after a faster later one (last-writer-wins).
    @ObservationIgnored private var comparisonTask: Task<Void, Never>?

    public init(
        friendStorage: FriendStoring? = nil,
        workoutStorage: WorkoutStoring? = nil,
        exerciseStorage: ExerciseStoring? = nil,
        exportWorkoutUseCase: ExportWorkoutUseCase? = nil,
        loadFriendComparisonUseCase: LoadFriendComparisonUseCase? = nil
    ) {
        self.friendStorage = friendStorage ?? Container.shared.friendStorage()
        self.workoutStorage = workoutStorage ?? Container.shared.workoutStorage()
        self.exerciseStorage = exerciseStorage ?? Container.shared.exerciseStorage()
        self.exportWorkoutUseCase = exportWorkoutUseCase ?? Container.shared.exportWorkoutUseCase()
        self.loadFriendComparisonUseCase = loadFriendComparisonUseCase ?? Container.shared.loadFriendComparisonUseCase()
    }

    public func exerciseCount(for workout: Workout) -> Int {
        MuscleCategoryGroup.allCases.reduce(0) { count, category in
            count + exerciseStorage.loadForWorkout(workoutId: workout.id, category: category).count
        }
    }

    // MARK: - Public actions

    public func toggleExpanded() {
        isExpanded.toggle()
        if isExpanded {
            autoSelectFriendIfNeeded()
        }
    }

    public func selectFriend(_ friend: Friend) {
        selectedFriendId = friend.id
        reloadComparison()
    }

    public func deleteFriend(_ friend: Friend) {
        friendStorage.deleteFriend(id: friend.id)
        if selectedFriendId == friend.id {
            selectedFriendId = nil
            comparison = nil
            comparisonError = nil
            autoSelectFriendIfNeeded()
        }
    }

    /// Called from UserRowView when the user taps their own row.
    public func requestExport() {
        showingExportPicker = true
    }

    /// Called from ExportWorkoutPickerSheet after the user selects a workout.
    public func requestShare(for workout: Workout) {
        do {
            let json = try exportWorkoutUseCase.execute(workout: workout)
            let fileURL = WorkoutShareFileWriter.write(json: json, name: workout.name, fileExtension: "fitnessfriend")
            workoutToShare = WorkoutShareItem(workout: workout, json: json, fileURL: fileURL)
        } catch {
            exportErrorMessage = WorkoutShareError.exportFailed.errorDescription
        }
    }

    public func friendAdded() {
        showingAddFriend = false
        autoSelectFriendIfNeeded()
    }

    // MARK: - Computed

    public var allWorkouts: [Workout] { workoutStorage.workouts }
    public var myNickname: String {
        // ProfileStore reads from UserDefaults; access via UserDefaults directly
        // to avoid a FitnessProfile dependency in this package.
        UserDefaults.standard.string(forKey: "userNickname") ?? "Me"
    }

    // MARK: - Private

    private func autoSelectFriendIfNeeded() {
        guard selectedFriendId == nil else { return }
        if friends.count == 1 {
            selectedFriendId = friends[0].id
            reloadComparison()
        }
    }

    private func reloadComparison() {
        // Clear synchronously so a stale comparison/error from the previously
        // selected friend never shows while the new load is in flight.
        comparisonTask?.cancel()
        comparison = nil
        comparisonError = nil
        guard let friend = selectedFriend,
              let workout = workoutStorage.currentWorkout else {
            return
        }
        comparisonTask = Task {
            do {
                let result = try loadFriendComparisonUseCase.execute(friend: friend, myWorkout: workout)
                // Drop the result if the selection moved on while we loaded.
                guard !Task.isCancelled, selectedFriendId == friend.id else { return }
                comparison = result
                comparisonError = nil
            } catch {
                guard !Task.isCancelled, selectedFriendId == friend.id else { return }
                comparison = nil
                comparisonError = "Comparison data could not be loaded."
            }
        }
    }
}
