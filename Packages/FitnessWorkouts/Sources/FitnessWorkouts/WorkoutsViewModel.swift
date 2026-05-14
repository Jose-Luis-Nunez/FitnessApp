import Foundation
import SwiftUI
import Observation
import FitnessCore
import FitnessStorage
import Factory

/// Identifiable wrapper that drives `.sheet(item:)` for the iOS share sheet —
/// carries both the source workout (for the sheet identity) and the precomputed
/// JSON (so the export is done synchronously up-front, not inside the SwiftUI
/// `content` builder where it could re-run on every body re-eval).
///
/// `fileURL` points at a tmp-dir `.json` file with sanitized filename derived
/// from `workout.name`. Sharing the file URL (instead of the raw JSON string)
/// makes iOS treat the export as a true file attachment in Mail/Messages, a
/// proper AirDrop file transfer, a "Save to Files" target, etc. If file-write
/// fails (extremely rare on iOS tmp dir), `fileURL` stays nil and the caller
/// falls back to sharing the JSON string.
public struct WorkoutShareItem: Identifiable {
    public let id: UUID
    public let workout: Workout
    public let json: String
    public let fileURL: URL?

    public init(workout: Workout, json: String, fileURL: URL? = nil) {
        self.id = workout.id
        self.workout = workout
        self.json = json
        self.fileURL = fileURL
    }
}

@Observable
@MainActor
public final class WorkoutsViewModel {
    public var showingFABOptions = false
    public var showingCreateWorkoutFullScreen = false
    public var showingImportWorkoutFullScreen = false
    public var showingRenameWorkout = false
    public var showingDeleteConfirmation = false
    public var selectedWorkoutForAction: Workout?
    public var newWorkoutName = ""
    public var renameWorkoutName = ""
    public var selectedMuscleGroups: Set<MuscleCategoryGroup> = []
    /// Drives the `.sheet(item:)` that presents the iOS share sheet. Set by
    /// `requestShare(for:)` after the workout JSON has been computed.
    public var workoutToShare: WorkoutShareItem?
    public var exportErrorMessage: String?

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
        guard !newWorkoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let workout = storageService.createWorkout(name: newWorkoutName, selectedCategories: selectedMuscleGroups)
        storageService.setCurrentWorkout(workout)

        newWorkoutName = ""
        selectedMuscleGroups = []
        showingCreateWorkoutFullScreen = false
    }

    public func selectWorkout(_ workout: Workout) {
        storageService.setCurrentWorkout(workout)
    }

    public func duplicateWorkout(_ workout: Workout) {
        let duplicatedWorkout = duplicateWorkoutUseCase.execute(workout)
        storageService.setCurrentWorkout(duplicatedWorkout)
        showingFABOptions = false
    }

    /// Deletes the workout. Enforces the invariant that at least one workout must remain —
    /// matches the UI affordance `canDeleteWorkout` so the rule lives in exactly one place.
    public func deleteWorkout(_ workout: Workout) {
        guard canDeleteWorkout else { return }
        deleteWorkoutUseCase.execute(workout)
        showingFABOptions = false
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

    public func showFABOptions(for workout: Workout) {
        selectedWorkoutForAction = workout
        showingFABOptions = true
    }

    public func showCreateWorkout() {
        newWorkoutName = "Workout \(workouts.count + 1)"
        selectedMuscleGroups = []
        showingCreateWorkoutFullScreen = true
    }

    /// Opens the Import Workout sheet. The plan spec is explicit that
    /// imported workouts do NOT become current — they only appear in the list.
    public func showImportWorkout() {
        showingImportWorkoutFullScreen = true
    }

    /// Called by the import sheet after a successful import. Per spec, the
    /// imported workout is NOT auto-activated — the user has to tap it to
    /// switch. The storage service already triggered a reload of `workouts`,
    /// so the new entry appears in the grid automatically — no state mutation
    /// needed here.
    ///
    /// The method exists as a deliberate seam: any future post-import effect
    /// the WorkoutsScreen would want to drive from a known-imported-workout
    /// (scroll-to-newly-imported, brief highlight ring, success toast, send
    /// analytics) plugs in here without changing the ImportWorkoutView
    /// callback contract. Keep it even if the body stays empty.
    public func handleImported(_ workout: Workout) {
        _ = workout
    }

    /// Triggers the iOS share sheet for a workout. Synchronously computes the
    /// JSON via `ExportWorkoutUseCase`, writes it to a `.json` file in the
    /// tmp directory (filename = sanitized workout name), and populates
    /// `workoutToShare` with both the file URL and the raw JSON string. The
    /// share sheet uses the file URL so iOS treats it as a proper file
    /// attachment in Mail/Messages/AirDrop/Files. If the file-write fails
    /// (extremely rare in iOS tmp), the share still works with the JSON
    /// string fallback. If JSON encoding itself fails, surface via
    /// `exportErrorMessage` for the alert.
    public func requestShare(for workout: Workout) {
        do {
            let json = try exportWorkoutUseCase.execute(workout: workout)
            let fileURL = writeShareFile(json: json, workout: workout)
            workoutToShare = WorkoutShareItem(workout: workout, json: json, fileURL: fileURL)
            hideFABOptions()
        } catch {
            exportErrorMessage = WorkoutShareError.exportFailed.errorDescription
        }
    }

    /// Writes the JSON content to a tmp file named
    /// `<sanitized-workout-name>.fitnessworkout`. The `.fitnessworkout`
    /// extension is exclusively owned by FitnessApp (custom UTType
    /// `com.fitnesspro.workout-share` in Info.plist) so iOS surfaces
    /// FitnessApp as the "Open in" target on the receiving device — avoiding
    /// the iOS 17+ "non-owner of public.json can't be default-open" trap.
    /// The file's content is still JSON; only the extension differs.
    /// Returns the file URL on success, `nil` on any I/O failure. Callers
    /// must handle the `nil` case by sharing the raw JSON string instead.
    private func writeShareFile(json: String, workout: Workout) -> URL? {
        let filename = Self.sanitizeFilename(workout.name)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(filename).fitnessworkout")
        do {
            try json.data(using: .utf8)?.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    /// Removes filesystem-unsafe characters from a workout name so it can
    /// become a filename. Replaces each of `/ \ ? % * | " < > :` with `_`,
    /// collapses consecutive underscores to a single one (so `???` doesn't
    /// produce `___.fitnessworkout`), trims surrounding whitespace, and
    /// falls back to `"workout"` if the result is empty or consists solely
    /// of underscores.
    static func sanitizeFilename(_ name: String) -> String {
        var result = name
        for ch in "/\\?%*|\"<>:" {
            result = result.replacingOccurrences(of: String(ch), with: "_")
        }
        result = result.replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.isEmpty || result.allSatisfy({ $0 == "_" }) {
            return "workout"
        }
        return result
    }

    public func toggleMuscleGroup(_ group: MuscleCategoryGroup) {
        if selectedMuscleGroups.contains(group) {
            selectedMuscleGroups.remove(group)
        } else {
            selectedMuscleGroups.insert(group)
        }
    }

    public func isMuscleGroupSelected(_ group: MuscleCategoryGroup) -> Bool {
        selectedMuscleGroups.contains(group)
    }

    public func showRenameWorkout(for workout: Workout) {
        selectedWorkoutForAction = workout
        renameWorkoutName = workout.name
        showingRenameWorkout = true
        showingFABOptions = false
    }

    public func hideFABOptions() {
        showingFABOptions = false
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
        hideFABOptions()
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

    public func getExerciseCount(for workout: Workout) -> Int {
        var totalCount = 0

        for category in MuscleCategoryGroup.allCases {
            let exercises = exerciseStorageService.loadForWorkout(workoutId: workout.id, category: category)
            totalCount += exercises.count
        }

        return totalCount
    }
}
