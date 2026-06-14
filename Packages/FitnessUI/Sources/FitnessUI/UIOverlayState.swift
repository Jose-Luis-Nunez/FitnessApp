import Foundation
import Observation

@Observable
@MainActor
public final class UIOverlayState {
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
    public var isCancellingTraining: Bool = false
    /// Reflects whether the system keyboard is currently visible. Consumed by
    /// the root layout to hide the glass bottom bar while the user edits a
    /// text field (otherwise the bar sits directly above the keyboard and
    /// looks like a second, conflicting toolbar).
    public var isKeyboardVisible: Bool = false

    public init() {}
}
