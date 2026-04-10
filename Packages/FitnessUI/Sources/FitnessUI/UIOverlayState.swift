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

    public init() {}
}
