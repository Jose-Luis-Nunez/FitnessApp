import SwiftUI

/// Bundles the three modifiers that drive the workout-import flow on
/// `WorkoutsScreen` so the screen body stays scannable:
/// 1. The `.fullScreenCover` that hosts `ImportWorkoutView`,
/// 2. The `.onChange` that catches `WorkoutImportCoordinator.pendingImportText`
///    (App-level `.onOpenURL` deposits → screen snapshots → opens sheet),
/// 3. The `.onChange` that resets the snapshot when the sheet closes.
///
/// The internal `pendingImportText` `@State` decouples the sheet's
/// `initialText` init-arg from the coordinator's mutable state, so we can
/// `clearPending()` on the coordinator immediately without losing the value
/// the sheet is supposed to display.
struct WorkoutImportFlowModifier: ViewModifier {
    @Bindable var viewModel: WorkoutsViewModel
    var importCoordinator: WorkoutImportCoordinator

    @State private var pendingImportText: String?

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $viewModel.showingImportWorkoutFullScreen) {
                ImportWorkoutView(
                    isPresented: $viewModel.showingImportWorkoutFullScreen,
                    initialText: pendingImportText,
                    onImported: { _ in }
                )
            }
            .onChange(of: importCoordinator.pendingImportText) { _, newText in
                // App-level `.onOpenURL` deposits the file contents into the
                // coordinator. Snapshot the value into local state, clear the
                // coordinator (so a future manual-paste open doesn't re-prefill
                // with stale content), then open the import sheet.
                guard let newText, !newText.isEmpty else { return }
                pendingImportText = newText
                importCoordinator.clearPending()
                viewModel.showingImportWorkoutFullScreen = true
            }
            .onChange(of: viewModel.showingImportWorkoutFullScreen) { _, isOpen in
                // Reset the snapshot once the sheet closes so a subsequent
                // manual "Import workout" tap starts with an empty editor.
                if !isOpen { pendingImportText = nil }
            }
    }
}

extension View {
    /// Attach the workout-import flow (sheet + coordinator-observer wiring) to
    /// a view. Typically applied once at the root of `WorkoutsScreen`.
    func workoutImportFlow(
        viewModel: WorkoutsViewModel,
        coordinator: WorkoutImportCoordinator
    ) -> some View {
        modifier(WorkoutImportFlowModifier(viewModel: viewModel, importCoordinator: coordinator))
    }
}
