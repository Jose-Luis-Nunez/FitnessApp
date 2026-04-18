import SwiftUI
import FitnessCore
import FitnessUI

/// Connects the `TrainingCoordinator`'s feedback presentation flag to the
/// `FeedbackSheetView` via a native `.sheet(...)` with `.large` detent —
/// the **same presentation pattern as `AnalyticsView`** (see
/// `InactiveCardView` / `ActiveCardView` / `IdleActiveCardView`). The
/// component itself is a zero-size `Color.clear` mount point inside the
/// training flow's view tree — its only job is to own the presentation
/// modifier and to lazily instantiate `FeedbackViewModel` per presentation.
///
/// Why `.sheet` (and not `.fullScreenCover` or `OverlaySheetContainer`):
/// - Native sheet renders the iOS-system **grabber** automatically, matching
///   the look of `AnalyticsView` exactly (where the user expects to see a
///   small horizontal handle at the top).
/// - `.large` detent makes the sheet effectively full-screen for the form
///   content, while still leaving the status bar visible and a thin strip of
///   the underlying view above the grabber.
/// - Native pull-to-dismiss is the system-standard gesture and routes through
///   our `presentationBinding.set(false)` automatically, no custom gesture
///   handling required.
///
/// The `UIOverlayState.isEditingSheetVisible` flag is set while the sheet is
/// visible so the app-level bottom action bar hides, matching the behaviour
/// of `TrainingPickerComponent` and `MuscleCategoryView`.
public struct FeedbackSheetComponent: View {
    @Bindable public var coordinator: TrainingCoordinator
    public let category: MuscleCategoryGroup?

    @Environment(UIOverlayState.self) private var overlayState
    @State private var viewModel: FeedbackViewModel?

    public init(coordinator: TrainingCoordinator, category: MuscleCategoryGroup? = nil) {
        self.coordinator = coordinator
        self.category = category
    }

    public var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .sheet(isPresented: presentationBinding) {
                if let vm = viewModel {
                    FeedbackSheetView(
                        viewModel: vm,
                        isPresented: presentationBinding
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(AppStyle.Color.black)
                }
            }
            .onChange(of: coordinator.isFeedbackSheetPresented) { _, isPresented in
                overlayState.isEditingSheetVisible = isPresented
                if isPresented, let exercise = coordinator.currentExercise {
                    viewModel = FeedbackViewModel(
                        exerciseId: exercise.id,
                        exerciseCategory: category
                    )
                } else if !isPresented {
                    viewModel = nil
                }
            }
    }

    /// Two-way bridge between SwiftUI's presentation API and the coordinator's
    /// state. Writing `false` closes the feedback flow via the coordinator so
    /// any downstream consumers (e.g. overlay flags, analytics) react.
    private var presentationBinding: Binding<Bool> {
        Binding(
            get: { coordinator.isFeedbackSheetPresented },
            set: { newValue in
                if !newValue { coordinator.closeFeedback() }
            }
        )
    }
}
