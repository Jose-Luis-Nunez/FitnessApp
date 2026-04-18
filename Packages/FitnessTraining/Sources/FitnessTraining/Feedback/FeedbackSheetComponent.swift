import SwiftUI
import FitnessCore
import FitnessUI

/// Connects the TrainingCoordinator's feedback presentation flag to the
/// FeedbackSheetView. The ViewModel is created lazily (and recreated on each
/// presentation) so that each open starts from a clean state. While the sheet
/// is visible, the global `UIOverlayState.isEditingSheetVisible` flag is set
/// to true — this hides the bottom action bar (see `FitnessAppApp.swift`),
/// matching how the Training picker and category edit sheets behave.
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
        Group {
            if coordinator.isFeedbackSheetPresented, let vm = viewModel {
                FeedbackSheetView(
                    viewModel: vm,
                    isPresented: Binding(
                        get: { coordinator.isFeedbackSheetPresented },
                        set: { newValue in
                            if !newValue { coordinator.closeFeedback() }
                        }
                    )
                )
                .zIndex(99998)
            } else {
                EmptyView()
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
}
