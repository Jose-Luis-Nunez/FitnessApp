import SwiftUI
import FitnessCore
import FitnessUI

// MARK: - Training Picker Component

public struct TrainingPickerComponent: View {
    @Bindable public var coordinator: TrainingCoordinator
    @Environment(UIOverlayState.self) private var overlayState

    @State private var isProcessingSaveCancel = false

    public init(coordinator: TrainingCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        if let vm = coordinator.focusedSession, vm.isEditing {
            TrainingPickerContent(
                vm: vm,
                overlayState: overlayState,
                isProcessingSaveCancel: $isProcessingSaveCancel
            )
        } else {
            EmptyView()
        }
    }
}

private struct TrainingPickerContent: View {
    @Bindable var vm: ActiveSetViewModel
    var overlayState: UIOverlayState
    @Binding var isProcessingSaveCancel: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea(.all)
                .onTapGesture {
                    vm.isEditing = false
                }
                .onAppear {
                    overlayState.isEditingSheetVisible = true
                }

            ActiveSetEditPickerView(
                title: {
                    switch vm.editMode {
                    case .less: "Less"
                    case .more: "More"
                    case .edit: "Edit"
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
                    vm.isEditing = false
                    vm.pendingEditIndex = nil

                    if !vm.isLastSetCompleted {
                        vm.startNextSet()
                    }

                    Task {
                        try? await Task.sleep(for: .milliseconds(500))
                        isProcessingSaveCancel = false
                    }
                },
                onCancel: {
                    guard !isProcessingSaveCancel else {
                        return
                    }
                    isProcessingSaveCancel = true

                    vm.isEditing = false
                    vm.pendingEditIndex = nil

                    Task {
                        try? await Task.sleep(for: .milliseconds(500))
                        isProcessingSaveCancel = false
                    }
                },
                saveDisabled: !vm.isInputValid
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .shadow(radius: 5)
            .zIndex(99999)
            .ignoresSafeArea(edges: .all)
            .onDisappear { overlayState.isEditingSheetVisible = false }
        }
        .id("picker-\(vm.isEditing)")
    }
}
