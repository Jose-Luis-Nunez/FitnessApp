import Foundation
import Observation
import CoreGraphics

/// Drives the exercise multi-select editing mode that the three-dots mini-menu
/// starts (deactivate / activate several exercises at once).
public enum ExerciseSelectionMode: Sendable {
    case none
    case deactivate
    case activate
}

@Observable
@MainActor
public final class UIOverlayState {
    /// Vertical room the training mini bar's plate currently claims above the
    /// tab row, or 0 when no mini bar is showing.
    ///
    /// Published by the bar, which is the only view that can measure it, and
    /// read by bottom-anchored page chrome that would otherwise sit under the
    /// opaque plate. It exists because the alternative — each consumer carrying
    /// its own hand-measured constant — drifts apart the moment the bar's
    /// spacing or title font changes, and the failure is silent: content simply
    /// disappears under the plate.
    public var trainingMiniBarClearance: CGFloat = 0

    public var isEditingSheetVisible: Bool = false
    public var showCategoryMiniMenu: Bool = false
    public var showSelectionMiniMenu: Bool = false
    public var showWorkoutsMiniMenu: Bool = false
    public var showWorkoutDropdown: Bool = false
    public var showWorkoutSettingsMenu: Bool = false
    public var showTrainingMiniMenu: Bool = false
    /// Driven by the bottom-bar "Training" tab when no default workout is set:
    /// shows a floating picker so the user can choose which workout becomes the
    /// default (and is then launched straight into its category selection).
    public var showDefaultWorkoutPicker: Bool = false
    /// Reflects whether the system keyboard is currently visible. Consumed by
    /// the root layout to hide the glass bottom bar while the user edits a
    /// text field (otherwise the bar sits directly above the keyboard and
    /// looks like a second, conflicting toolbar).
    public var isKeyboardVisible: Bool = false

    // MARK: - Exercise deactivate / activate

    /// The active multi-select editing mode. `.none` means normal browsing.
    /// Started by the "Deactivate Exercise" / "Activate Exercise" mini-menu items;
    /// while non-`.none`, exercise rows show a leading radio button.
    public var exerciseSelectionMode: ExerciseSelectionMode = .none
    /// IDs ticked in the current multi-select mode.
    public var selectedExerciseIds: Set<UUID> = []
    /// Commit trigger: the morphed bottom bar flips this to `true`; the host list
    /// observes it, applies the de/activation to `selectedExerciseIds`, then
    /// resets the mode. Cancel simply resets `exerciseSelectionMode`/ids.
    public var commitExerciseSelection: Bool = false

    /// Toggles one exercise's membership in the current multi-select.
    public func toggleSelection(_ id: UUID) {
        if selectedExerciseIds.contains(id) {
            selectedExerciseIds.remove(id)
        } else {
            selectedExerciseIds.insert(id)
        }
    }

    /// Clears all multi-select state (Cancel, or after a committed Save).
    public func endExerciseSelection() {
        exerciseSelectionMode = .none
        selectedExerciseIds = []
        commitExerciseSelection = false
    }

    public init() {}
}
