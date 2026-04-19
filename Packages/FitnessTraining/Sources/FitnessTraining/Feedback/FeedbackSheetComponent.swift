import SwiftUI
import FitnessCore
import FitnessUI

/// Connects the `TrainingCoordinator`'s feedback presentation flag to the
/// `FeedbackSheetView` via a native `.sheet(...)` with **two** progressive
/// detents — the **same presentation pattern as `AnalyticsView`** (see
/// `InactiveCardView` / `ActiveCardView` / `IdleActiveCardView`). The
/// component itself is a zero-size `Color.clear` mount point inside the
/// training flow's view tree — its only job is to own the presentation
/// modifier and to lazily instantiate `FeedbackViewModel` per presentation.
///
/// Why `.sheet` (and not `.fullScreenCover` or `OverlaySheetContainer`):
/// - Native sheet renders the iOS-system **grabber** automatically, matching
///   the look of `AnalyticsView` exactly (where the user expects to see a
///   small horizontal handle at the top).
/// - Two `.presentationDetents` (a content-fitted `.height(...)` and `.large`)
///   create a progressive-disclosure UX: the sheet opens small showing only
///   the title, the four Physical-Symptom tiles, and the Hide/Save action
///   bar. As soon as the user selects any symptom, it auto-expands to
///   `.large`; deselecting all symptoms collapses it back. The user can also
///   drag manually between detents.
/// - The small detent height is measured at runtime via a `PreferenceKey`
///   inside `FeedbackSheetView` (`onInitialContentHeightChange`) and stored
///   in `smallDetentHeight`, so the small state always exactly fits its
///   content (Dynamic Type / locale-safe).
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

    /// Conservative initial estimate for the small/initial detent height while
    /// the actual content height has not yet been measured. Replaced by the
    /// `FeedbackSheetView` measurement on the first layout pass; the brief
    /// snap is invisible because both happen in the same render cycle on
    /// modern iOS.
    private static let initialDetentEstimate: CGFloat = 380
    /// Approximate height of the sticky bottom action bar (Hide/Save buttons
    /// + the 24pt top-padding the sheet adds around it). Added to the
    /// content-block height reported by `FeedbackSheetView` to compute the
    /// final small detent height.
    private static let actionBarHeight: CGFloat = 84

    @State private var smallDetentHeight: CGFloat = initialDetentEstimate
    @State private var selectedDetent: PresentationDetent = .height(initialDetentEstimate)

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
                        isPresented: presentationBinding,
                        onInitialContentHeightChange: { contentHeight in
                            let proposed = contentHeight + Self.actionBarHeight
                            guard abs(proposed - smallDetentHeight) > 0.5 else { return }
                            smallDetentHeight = proposed
                            // If the small detent is currently selected, keep it
                            // selected with the new height so the sheet snaps to
                            // the freshly measured size on the next layout.
                            if vm.symptoms.isEmpty {
                                selectedDetent = .height(proposed)
                            }
                        }
                    )
                    .presentationDetents([.height(smallDetentHeight), .large], selection: $selectedDetent)
                    .presentationDragIndicator(.visible)
                    .presentationBackground(AppStyle.Color.black)
                    .onChange(of: vm.symptoms.isEmpty) { _, isEmpty in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedDetent = isEmpty ? .height(smallDetentHeight) : .large
                        }
                    }
                }
            }
            .onChange(of: coordinator.isFeedbackSheetPresented) { _, isPresented in
                overlayState.isEditingSheetVisible = isPresented
                if isPresented, let exercise = coordinator.currentExercise {
                    // Bind the view model to the active session so save / re-save
                    // operate on the per-session row in storage. If for some
                    // reason there is no active session id (sheet opened outside
                    // an active training, edge case), fall back to a fresh UUID
                    // — the sheet still works, just without session linkage.
                    let sessionId = coordinator.currentSessionId(for: exercise.id) ?? UUID()
                    let vm = FeedbackViewModel(
                        exerciseId: exercise.id,
                        sessionId: sessionId,
                        exerciseCategory: category,
                        draftStore: coordinator.draftStore,
                        currentFocusedExerciseId: { [weak coordinator] in
                            coordinator?.focusedExerciseId
                        }
                    )
                    viewModel = vm
                    // Open small for a fresh sheet (no symptoms yet) and large
                    // when re-editing an existing draft / saved entry so the
                    // user immediately sees Pain / Energy / Notes.
                    selectedDetent = vm.symptoms.isEmpty
                        ? .height(smallDetentHeight)
                        : .large
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
