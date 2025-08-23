import SwiftUI

// MARK: - Training Picker Component
struct TrainingPickerComponent: View {
    @ObservedObject var coordinator: TrainingCoordinator
    @EnvironmentObject private var overlayState: UIOverlayState
    
    // State management for picker visibility and processing
    @State private var isProcessingSaveCancel = false
    @State private var isEditPickerVisible = false
    
    var body: some View {
        Group {
            if coordinator.activeSetViewModel.isEditing || isEditPickerVisible {
                // Signal: bring sheet to front, hide menu bar
                Color.clear
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
                    weightOptions: WeightOptionsGenerator.generateTrainingWeightOptions(),
                    onSave: { newReps, newWeight in
                        guard !isProcessingSaveCancel else { 
                            return 
                        }
                        isProcessingSaveCancel = true
                        
                        // Save the edited values
                        coordinator.activeSetViewModel.updateCurrentReps(newReps, newWeight)
                        coordinator.activeSetViewModel.isEditing = false
                        coordinator.activeSetViewModel.pendingEditIndex = nil
                        isEditPickerVisible = false  // Force picker to close
                        
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
                        isEditPickerVisible = false  // Force picker to close
                        
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
                .transition(.move(edge: .bottom).combined(with: .opacity).animation(.easeOut(duration: 0.25)))
                .zIndex(1000)  // Higher than bottom menu bar
                .ignoresSafeArea(edges: .bottom)
                .onDisappear { overlayState.isEditingSheetVisible = false }
            }
        }
        .onChange(of: coordinator.activeSetViewModel.isEditing) { isEditing in
            if isEditing && !isEditPickerVisible {
                isEditPickerVisible = true
            }
        }
    }
    

}
