import SwiftUI
import FitnessCore
import FitnessResources
import FitnessUI

// MARK: - Training Picker Component

public struct TrainingPickerComponent: View {
    @Bindable public var coordinator: TrainingCoordinator
    /// Height of the training sheet this picker is opened from. Less/More is a
    /// sibling of the training and feedback sheets in the same flow, so all
    /// three are given the one measured height rather than sizing themselves.
    public let sheetHeight: CGFloat
    @Environment(UIOverlayState.self) private var overlayState

    @State private var isProcessingSaveCancel = false

    public init(coordinator: TrainingCoordinator, sheetHeight: CGFloat) {
        self.coordinator = coordinator
        self.sheetHeight = sheetHeight
    }

    private var isEditing: Bool {
        coordinator.focusedSession?.isEditing == true
    }

    /// Mirrors `FeedbackSheetComponent`: the conditional content lives inside a
    /// container that is always present, so the `.animation(value:)` below has a
    /// stable view to attach to and the insert/remove transition actually runs.
    /// Putting the animation on the `if` itself would give it nothing to
    /// animate — the view is simply gone on the next frame.
    public var body: some View {
        ZStack {
            if let vm = coordinator.focusedSession, vm.isEditing {
                TrainingPickerContent(
                    vm: vm,
                    overlayState: overlayState,
                    sheetHeight: sheetHeight,
                    isProcessingSaveCancel: $isProcessingSaveCancel
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(isEditing)
        .animation(.easeInOut(duration: Self.presentationDuration), value: isEditing)
    }

    /// Same duration as the feedback sheet, so the two sheets in this flow open
    /// and close at one pace.
    static let presentationDuration: TimeInterval = 0.25
}

private struct TrainingPickerContent: View {
    @Bindable var vm: ActiveSetViewModel
    var overlayState: UIOverlayState
    let sheetHeight: CGFloat
    @Binding var isProcessingSaveCancel: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            // The backdrop fades in place while only the sheet slides, so it
            // must sit outside the transitioned view.
            Color.black.opacity(AppStyle.Opacity.overlayBackdrop)
                .ignoresSafeArea(.all)
                .onTapGesture { cancelEditing() }

            ActiveSetEditPickerView(
                title: {
                    switch vm.editMode {
                    case .less: AppText.actionLess
                    case .more: AppText.actionMore
                    case .edit: AppText.trainingEdit
                    case .achievement: AppText.trainingSetResult
                    }
                }(),
                selectedReps: $vm.repsInput,
                selectedWeight: $vm.weightInput,
                repsRange: 1...30,
                weightOptions: WeightOptionsGenerator.trainingWeightOptions,
                onSave: { newReps, newWeight in
                    guard !isProcessingSaveCancel else {
                        return
                    }
                    isProcessingSaveCancel = true

                    vm.updateCurrentReps(newReps, newWeight)
                    withAnimation(
                        .easeInOut(duration: TrainingPickerComponent.presentationDuration)
                    ) {
                        vm.isEditing = false
                    }
                    vm.pendingEditIndex = nil

                    if !vm.isLastSetCompleted {
                        vm.startNextSet()
                    }

                    Task {
                        try? await Task.sleep(for: .milliseconds(500))
                        isProcessingSaveCancel = false
                    }
                },
                onCancel: { cancelEditing() },
                saveDisabled: !vm.isInputValid,
                fixedHeight: sheetHeight,
                surface: .ambient,
                ownsPresentation: false
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .shadow(radius: 5)
            .zIndex(99999)
            .ignoresSafeArea(edges: .all)
            .hidesBottomBarWhilePresented(overlayState)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func cancelEditing() {
        guard !isProcessingSaveCancel else {
            return
        }
        isProcessingSaveCancel = true

        withAnimation(
            .easeInOut(duration: TrainingPickerComponent.presentationDuration)
        ) {
            vm.isEditing = false
        }
        vm.pendingEditIndex = nil

        Task {
            try? await Task.sleep(for: .milliseconds(500))
            isProcessingSaveCancel = false
        }
    }
}
