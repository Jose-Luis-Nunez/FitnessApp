import Combine
import Foundation

public final class UIOverlayState: ObservableObject {
    @Published public var isEditingSheetVisible: Bool = false
    @Published public var showCategoryMiniMenu: Bool = false
    @Published public var showSelectionMiniMenu: Bool = false
    @Published public var showWorkoutsMiniMenu: Bool = false
    @Published public var showWorkoutDropdown: Bool = false
    @Published public var showWorkoutSettingsMenu: Bool = false
    @Published public var showTrainingMiniMenu: Bool = false
    @Published public var isCancellingTraining: Bool = false

    public init() {}
}
