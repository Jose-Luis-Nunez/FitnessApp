import SwiftUI

public extension View {
    /// Marks an editing / picker sheet as visible for the lifetime of this
    /// view, so the app's glass bottom bar hides while the sheet is up
    /// (`UIOverlayState.isEditingSheetVisible`). Apply it to the sheet/overlay
    /// content that is conditionally mounted.
    ///
    /// `UIOverlayState` is passed explicitly rather than read via `@Environment`
    /// so this stays usable in previews / snapshot tests that don't inject it,
    /// and so the cross-cutting "hide the bottom bar" concern lives in one place
    /// instead of being hand-wired (and forgotten) at every call site.
    func hidesBottomBarWhilePresented(_ state: UIOverlayState) -> some View {
        onAppear { state.isEditingSheetVisible = true }
            .onDisappear { state.isEditingSheetVisible = false }
    }
}
