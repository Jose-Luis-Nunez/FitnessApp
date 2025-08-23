import SwiftUI

struct TrainingView: View {
    let exercise: Exercise
    let category: MuscleCategoryGroup
    @Binding var navigationPath: NavigationPath
    
    @StateObject private var trainingCoordinator: TrainingCoordinator
    @StateObject private var analyticsViewModel: AnalyticsViewModel
    @EnvironmentObject private var overlayState: UIOverlayState
    
    @State private var hasFinishedTraining = false
    @State private var isInitialLoad = true
    
    init(exercise: Exercise, category: MuscleCategoryGroup, navigationPath: Binding<NavigationPath>) {
        self.exercise = exercise
        self.category = category
        self._navigationPath = navigationPath
        
        // Create TrainingCoordinator for this specific training session
        _trainingCoordinator = StateObject(wrappedValue: TrainingCoordinator(
            findCategory: { _ in category },
            onExerciseUpdate: { updatedExercise, _ in
                // Update exercise using ExerciseManagementService
                let managementService = ExerciseManagementService()
                managementService.updateExercise(updatedExercise, category: category)
            },
            onExerciseReset: { exerciseToReset, _ in
                // Reset exercise using ExerciseManagementService
                let managementService = ExerciseManagementService()
                managementService.resetExercise(exerciseToReset, category: category)
            },
            onAddExercise: {
                // Not needed in dedicated training view
            },
            onResetAllExercises: {
                // Not needed in dedicated training view
            }
        ))
        
        _analyticsViewModel = StateObject(wrappedValue: AnalyticsViewModel())
    }
    
    private var safeAreaBottomInset: CGFloat {
        UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            AppStyle.Color.backgroundColor
                .ignoresSafeArea()
            
            // Only show content if training is active
            if trainingCoordinator.isTrainingActive {
                VStack(spacing: 0) {
                    Spacer().frame(height: 16)
                    
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Active Exercise Card
                            ExerciseCardContainerView(
                                viewModel: ExerciseCardViewModel(exercise: exercise) { updatedExercise in
                                    // Update exercise using ExerciseManagementService
                                    let managementService = ExerciseManagementService()
                                    managementService.updateExercise(updatedExercise, category: category)
                                },
                                onEdit: { exerciseToEdit in
                                    // Could implement exercise editing here if needed
                                },
                                isEditable: !trainingCoordinator.activeSetViewModel.isSetInProgress,
                                analyticsViewModel: analyticsViewModel,
                                activeSetViewModel: trainingCoordinator.activeSetViewModel,
                                onStart: { exerciseToStart in
                                    // Exercise is already started when view appears
                                },
                                onReset: { exerciseToReset in
                                    trainingCoordinator.resetExercise()
                                },
                                isActiveSetVisible: trainingCoordinator.isTrainingActive,
                                isResetEnabled: exercise.isCompleted
                            )
                            
                            // Training Session (ActiveSetView + TimerView)
                            TrainingSessionComponent(
                                coordinator: trainingCoordinator,
                                analyticsViewModel: analyticsViewModel
                            )
                        }
                        .padding(.horizontal, 0)
                        .padding(.bottom, safeAreaBottomInset + 120) // Space for FABs
                    }
                }
                
                // Training Action Bar (FABs)
                TrainingActionBarComponent(
                    coordinator: trainingCoordinator,
                    exercises: [exercise],
                    hasActiveExercise: trainingCoordinator.isTrainingActive
                )
                .padding(.bottom, safeAreaBottomInset + 12)
                
                // Training Picker Component
                TrainingPickerComponent(coordinator: trainingCoordinator)
            }
            
            // Training Mini Menu Overlay
            if overlayState.showTrainingMiniMenu {
                // Backdrop to dismiss on outside tap
                Color.black.opacity(0.001)
                    .ignoresSafeArea(.all)
                    .onTapGesture { overlayState.showTrainingMiniMenu = false }

                // Floating menu panel
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        MiniActionMenuView(
                            title: nil,
                            items: [
                                // Cancel Training
                                MiniActionMenuItem(
                                    icon: "xmark", 
                                    title: "Cancel", 
                                    isDestructive: true
                                ) {
                                    // Cancel the active training
                                    trainingCoordinator.activeSetViewModel.cancelActiveSet()
                                    overlayState.showTrainingMiniMenu = false
                                }
                            ],
                            width: min(UIScreen.main.bounds.width * 0.55, 320),
                            minHeight: 140
                        )
                        .padding(.trailing, 12)
                    }
                    .padding(.bottom, safeAreaBottomInset - 50)
                }
                .transition(.opacity)
                .zIndex(4)
            }
        }
        .customToolbar(title: exercise.name, navigationPath: $navigationPath, showBackButton: false)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Start training automatically when view appears
            trainingCoordinator.startTraining(for: exercise)
            // Mark that initial load is complete after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isInitialLoad = false
            }
        }
        .onReceive(trainingCoordinator.$isTrainingActive) { isActive in
            // Auto-navigate back when training is finished (ANY reason: completed, cancelled, reset)
            if !isActive && !hasFinishedTraining && !isInitialLoad && !navigationPath.isEmpty {
                hasFinishedTraining = true
                // Hide any overlay states before navigating back
                overlayState.showTrainingMiniMenu = false
                
                // Always navigate back when training becomes inactive
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Double check that we're still on the TrainingView before navigating back
                    if !navigationPath.isEmpty {
                        navigationPath.removeLast()
                    }
                }
            }
        }
        .onDisappear {
            // Clean up when leaving training view manually (back button, etc.)
            if trainingCoordinator.isTrainingActive {
                // Save analytics before leaving
                trainingCoordinator.finishExercise()
            }
            
            // Always clean up overlay states when leaving TrainingView
            overlayState.showTrainingMiniMenu = false
        }
    }
    
    #Preview {
        let sampleExercise = Exercise(
            id: UUID(),
            name: "Sample Exercise",
            weight: 20.0,
            reps: 12,
            sets: 3,
            isCompleted: false,
            iconName: "defaultChestIcon",
            category: .chest
        )
        
        NavigationStack {
            TrainingView(
                exercise: sampleExercise,
                category: .chest,
                navigationPath: .constant(NavigationPath())
            )
        }
        .environmentObject(UIOverlayState())
    }
}