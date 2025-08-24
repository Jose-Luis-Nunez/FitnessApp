import Foundation
import Combine

final class UIOverlayState: ObservableObject {
    @Published var isEditingSheetVisible: Bool = false
    // Increments to signal a Reset All request from the bottom bar
    @Published var resetAllNonce: Int = 0
    // Controls the small action menu in Category View (ellipsis button)
    @Published var showCategoryMiniMenu: Bool = false
    // Controls the small action menu in Category Selection View
    @Published var showSelectionMiniMenu: Bool = false
    // Controls the small action menu in Workouts View
    @Published var showWorkoutsMiniMenu: Bool = false
    // Controls the workout dropdown picker
    @Published var showWorkoutDropdown: Bool = false
    // Controls the workout settings mini menu (FAB options in WorkoutsScreen)
    @Published var showWorkoutSettingsMenu: Bool = false
    // Controls the mini menu in Training View
    @Published var showTrainingMiniMenu: Bool = false
    // Prevents customBackAction when cancelling training
    @Published var isCancellingTraining: Bool = false
}


