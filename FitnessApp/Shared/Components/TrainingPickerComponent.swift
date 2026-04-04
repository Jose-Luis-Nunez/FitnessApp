import SwiftUI

// MARK: - Training Picker Component
struct TrainingPickerComponent: View {
    @ObservedObject var coordinator: TrainingCoordinator
    @EnvironmentObject private var overlayState: UIOverlayState
    
    // State management for picker visibility and processing
    @State private var isProcessingSaveCancel = false
    
    var body: some View {
        // REMOVE Group wrapper - direct rendering
        if coordinator.activeSetViewModel.isEditing {
            
            // Fullscreen overlay to ensure visibility
            ZStack {
                // Semi-transparent background
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
                        
                        // Save the edited values
                        coordinator.activeSetViewModel.updateCurrentReps(newReps, newWeight)
                        coordinator.activeSetViewModel.isEditing = false
                        coordinator.activeSetViewModel.pendingEditIndex = nil
                        
                        // Force ActiveSetViewModel refresh
                        coordinator.activeSetViewModel.objectWillChange.send()
                        
                        // updateCurrentReps already incremented currentSet for active set
                        // Start timer for next set if not completed
                        if !coordinator.activeSetViewModel.isLastSetCompleted {
                            coordinator.activeSetViewModel.startNextSet()
                        }
                        
                        // Force UI refresh
                        coordinator.objectWillChange.send()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            // Additional UI refresh after short delay
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
                        
                        // ONLY reset editing state - DON'T touch timer or training state
                        coordinator.activeSetViewModel.isEditing = false
                        coordinator.activeSetViewModel.pendingEditIndex = nil
                        
                        // Force UI refresh to restore FABs
                        coordinator.objectWillChange.send()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isProcessingSaveCancel = false
                        }
                    },
                    saveDisabled: !coordinator.activeSetViewModel.isInputValid
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .shadow(radius: 5)
                .zIndex(99999)  // MAXIMUM zIndex to ensure visibility
                .ignoresSafeArea(edges: .all)  // Ignore ALL safe areas
                .onDisappear { overlayState.isEditingSheetVisible = false }
            }
            .id("picker-\(coordinator.activeSetViewModel.isEditing)")  // Force SwiftUI refresh
        } else {
            EmptyView()
        }
    }
    

}
