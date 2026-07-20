import Foundation
import Observation
import FitnessCore
import FitnessStorage
import Factory

/// Identifiable wrapper that drives `.sheet(item:)` for the iOS share sheet —
/// carries the source workout's stable id and the precomputed JSON (so the
/// export is done synchronously up-front, not inside the SwiftUI
/// `content` builder where it could re-run on every body re-eval).
///
/// `fileURL` points at a temporary `.fitnessworkout` file with a sanitized name derived
/// from `workout.name`. Sharing the file URL (instead of the raw JSON string)
/// makes iOS treat the export as a true file attachment in Mail/Messages, a
/// proper AirDrop file transfer, a "Save to Files" target, etc. If file-write
/// fails (extremely rare on iOS tmp dir), `fileURL` stays nil and the caller
/// falls back to sharing the JSON string.
public struct WorkoutShareItem: Identifiable {
    public let id: UUID
    public let json: String
    public let fileURL: URL?

    public init(workout: Workout, json: String, fileURL: URL? = nil) {
        self.id = workout.id
        self.json = json
        self.fileURL = fileURL
    }
}

@Observable
@MainActor
public final class WorkoutsViewModel {
    public var showingWorkoutOptions = false
    public var showingCreateWorkoutFullScreen = false
    public var showingImportWorkoutFullScreen = false
    public var showingRenameWorkout = false
    public var showingDeleteConfirmation = false
    public var selectedWorkoutForAction: Workout?
    public var newWorkoutName = ""
    public var newWorkoutType: WorkoutType?
    public var renameWorkoutName = ""
    /// Drives the `.sheet(item:)` that presents the iOS share sheet. Set by
    /// `requestShare(for:)` after the workout JSON has been computed.
    public var workoutToShare: WorkoutShareItem?
    public var exportErrorMessage: String?
    public var createErrorMessage: String?

    @ObservationIgnored private let storageService: WorkoutStoring
    @ObservationIgnored private let exerciseStorageService: ExerciseStoring
    @ObservationIgnored private let deleteWorkoutUseCase: DeleteWorkoutUseCase
    @ObservationIgnored private let duplicateWorkoutUseCase: DuplicateWorkoutUseCase
    @ObservationIgnored private let exportWorkoutUseCase: ExportWorkoutUseCase

    public var workouts: [Workout] { storageService.workouts }
    public var currentWorkout: Workout? { storageService.currentWorkout }
    public var defaultWorkout: Workout? { storageService.defaultWorkout }

    /// Designated initializer. Dependencies default to the Factory container registrations
    /// in production; tests pass explicit mocks for isolation (no `Container.shared` coupling).
    public init(
        workoutStorage: WorkoutStoring? = nil,
        exerciseStorage: ExerciseStoring? = nil,
        deleteWorkoutUseCase: DeleteWorkoutUseCase? = nil,
        duplicateWorkoutUseCase: DuplicateWorkoutUseCase? = nil,
        exportWorkoutUseCase: ExportWorkoutUseCase? = nil
    ) {
        self.storageService = workoutStorage ?? Container.shared.workoutStorage()
        self.exerciseStorageService = exerciseStorage ?? Container.shared.exerciseStorage()
        self.deleteWorkoutUseCase = deleteWorkoutUseCase ?? Container.shared.deleteWorkoutUseCase()
        self.duplicateWorkoutUseCase = duplicateWorkoutUseCase ?? Container.shared.duplicateWorkoutUseCase()
        self.exportWorkoutUseCase = exportWorkoutUseCase ?? Container.shared.exportWorkoutUseCase()
    }

    // MARK: - Workout Actions

    public func createNewWorkout() {
        guard !newWorkoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let selectedWorkoutType = newWorkoutType else { return }

        // Workouts are not category-restricted (the overview always shows all
        // five), so a new workout covers all categories — the storage default.
        let workout: Workout
        do {
            workout = try storageService.createWorkout(
                name: newWorkoutName,
                selectedCategories: Set(MuscleCategoryGroup.allCases),
                type: selectedWorkoutType
            )
        } catch {
            createErrorMessage = "Workout could not be saved."
            return
        }
        storageService.setCurrentWorkout(workout)

        createErrorMessage = nil
        newWorkoutName = ""
        newWorkoutType = nil
        showingCreateWorkoutFullScreen = false
    }

    public func selectWorkout(_ workout: Workout) {
        storageService.setCurrentWorkout(workout)
    }

    public func duplicateWorkout(_ workout: Workout) {
        let duplicatedWorkout = duplicateWorkoutUseCase.execute(workout)
        storageService.setCurrentWorkout(duplicatedWorkout)
        showingWorkoutOptions = false
    }

    /// Deletes the workout. Enforces the invariant that at least one workout must remain —
    /// matches the UI affordance `canDeleteWorkout` so the rule lives in exactly one place.
    public func deleteWorkout(_ workout: Workout) {
        guard canDeleteWorkout else { return }
        deleteWorkoutUseCase.execute(workout)
        showingWorkoutOptions = false
    }

    public func renameWorkout() {
        guard let workout = selectedWorkoutForAction,
              !renameWorkoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        storageService.renameWorkout(workout, newName: renameWorkoutName)

        renameWorkoutName = ""
        showingRenameWorkout = false
        selectedWorkoutForAction = nil
    }

    // MARK: - UI Actions

    public func showWorkoutOptions(for workout: Workout) {
        selectedWorkoutForAction = workout
        showingWorkoutOptions = true
    }

    public func showCreateWorkout() {
        newWorkoutName = ""
        newWorkoutType = nil
        createErrorMessage = nil
        showingCreateWorkoutFullScreen = true
    }

    /// Opens the Import Workout sheet. The plan spec is explicit that
    /// imported workouts do NOT become current — they only appear in the list.
    public func showImportWorkout() {
        showingImportWorkoutFullScreen = true
    }

    /// Triggers the iOS share sheet for a workout. Synchronously computes the
    /// JSON via `ExportWorkoutUseCase`, writes it to a `.fitnessworkout` file
    /// in the tmp directory (filename = sanitized workout name), and populates
    /// `workoutToShare` with both the file URL and the raw JSON string. The
    /// share sheet uses the file URL so iOS treats it as a proper file
    /// attachment in Mail/Messages/AirDrop/Files. If the file-write fails
    /// (extremely rare in iOS tmp), the share still works with the JSON
    /// string fallback. If JSON encoding itself fails, surface via
    /// `exportErrorMessage` for the alert.
    public func requestShare(for workout: Workout) {
        do {
            let json = try exportWorkoutUseCase.execute(workout: workout)
            let fileURL = WorkoutShareFileWriter.write(json: json, name: workout.name)
            workoutToShare = WorkoutShareItem(workout: workout, json: json, fileURL: fileURL)
            hideWorkoutOptions()
        } catch {
            exportErrorMessage = WorkoutShareError.exportFailed.errorDescription
        }
    }

    public func showRenameWorkout(for workout: Workout) {
        selectedWorkoutForAction = workout
        renameWorkoutName = workout.name
        showingRenameWorkout = true
        showingWorkoutOptions = false
    }

    public func hideWorkoutOptions() {
        showingWorkoutOptions = false
        showingDeleteConfirmation = false
        selectedWorkoutForAction = nil
    }

    public func showDeleteConfirmation() {
        showingDeleteConfirmation = true
    }

    public func confirmDelete() {
        if let workout = selectedWorkoutForAction {
            deleteWorkout(workout)
        }
        hideWorkoutOptions()
    }

    public func cancelDelete() {
        showingDeleteConfirmation = false
    }

    // MARK: - Queries

    public var canDeleteWorkout: Bool {
        workouts.count > 1
    }

    public func isDefaultWorkout(_ workout: Workout) -> Bool {
        defaultWorkout?.id == workout.id
    }

    public func setAsDefault(_ workout: Workout) {
        storageService.setAsDefaultWorkout(workout)
    }

    public func removeAsDefault() {
        storageService.removeAsDefaultWorkout()
    }

    public func exerciseCountsByWorkout() -> [UUID: Int] {
        exerciseStorageService.exerciseCountsByWorkout()
    }
}
