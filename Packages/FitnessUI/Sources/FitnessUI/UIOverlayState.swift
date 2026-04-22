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
    public var isCancellingTraining: Bool = false
    /// Reflects whether the system keyboard is currently visible. Consumed by
    /// the root layout to hide the glass bottom bar while the user edits a
    /// text field (otherwise the bar sits directly above the keyboard and
    /// looks like a second, conflicting toolbar).
    public var isKeyboardVisible: Bool = false

    public init() {}
}
