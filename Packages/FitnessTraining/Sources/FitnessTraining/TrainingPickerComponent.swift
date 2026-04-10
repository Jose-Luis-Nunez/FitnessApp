import SwiftUI
import FitnessCore
import FitnessUI

// MARK: - Training Picker Component

public struct TrainingPickerComponent: View {
    @ObservedObject public var coordinator: TrainingCoordinator
    @EnvironmentObject private var overlayState: UIOverlayState

    @State private var isProcessingSaveCancel = false

    public init(coordinator: TrainingCoordinator) {
        _coordinator = ObservedObject(wrappedValue: coordinator)
    }

    public var body: some View {
        if coordinator.activeSetViewModel.isEditing {

            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea(.all)
                    .onTapGesture {
                        coordinator.activeSetViewModel.isEditing = false
                    }
                    .onAppear {
                        overlayState.isEditingSheetVisible = true
                    }

                ActiveSetEditPickerView(
                    title: {
                        switch coordinator.activeSetViewModel.editMode {
                        case .less: "Verschlechtert"
                        case .more: "Verbessert"
                        case .edit: "Bearbeiten"
                        }
                    }(),
                    selectedReps: $coordinator.activeSetViewModel.repsInput,
                    selectedWeight: $coordinator.activeSetViewModel.weightInput,
                    repsRange: 1...30,
                    weightOptions: WeightOptionsGenerator.trainingWeightOptions,
                    onSave: { newReps, newWeight in
                        guard !isProcessingSaveCancel else {
                            return
                        }
                        isProcessingSaveCancel = true

                        coordinator.activeSetViewModel.updateCurrentReps(newReps, newWeight)
                        coordinator.activeSetViewModel.isEditing = false
                        coordinator.activeSetViewModel.pendingEditIndex = nil

                        coordinator.activeSetViewModel.objectWillChange.send()

                        if !coordinator.activeSetViewModel.isLastSetCompleted {
                            coordinator.activeSetViewModel.startNextSet()
                        }

                        coordinator.objectWillChange.send()

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            coordinator.objectWillChange.send()
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isProcessingSaveCancel = false
                        }
                    },
                    onCancel: {
                        guard !isProcessingSaveCancel else {
                            return
                        }
                        isProcessingSaveCancel = true

                        coordinator.activeSetViewModel.isEditing = false
                        coordinator.activeSetViewModel.pendingEditIndex = nil

                        coordinator.objectWillChange.send()

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isProcessingSaveCancel = false
                        }
                    },
                    saveDisabled: !coordinator.activeSetViewModel.isInputValid
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .shadow(radius: 5)
                .zIndex(99999)
                .ignoresSafeArea(edges: .all)
                .onDisappear { overlayState.isEditingSheetVisible = false }
            }
            .id("picker-\(coordinator.activeSetViewModel.isEditing)")
        } else {
            EmptyView()
        }
    }
}
