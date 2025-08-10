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
}


