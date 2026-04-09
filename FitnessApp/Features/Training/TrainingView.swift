import SwiftUI

struct TrainingView: View {
    let exercise: Exercise
    let category: MuscleCategoryGroup
    
    @EnvironmentObject private var router: AppRouter
    @StateObject private var trainingCoordinator: TrainingCoordinator
    @StateObject private var analyticsViewModel: AnalyticsViewModel
    @EnvironmentObject private var overlayState: UIOverlayState
    
    @State private var hasFinishedTraining = false
    @State private var isInitialLoad = true
    @State private var isManuallyNavigatingBack = false
    
    init(exercise: Exercise, category: MuscleCategoryGroup) {
        self.exercise = exercise
        self.category = category
        
        // Get or create the appropriate ActiveSetViewModel for this category from SessionTrainingCache
        let categoryActiveSetVM: ActiveSetViewModel
        if let existing = SessionTrainingCache.shared.activeSetVMs[category] {
            categoryActiveSetVM = existing
        } else {
            let newVM = ActiveSetViewModel()
            SessionTrainingCache.shared.activeSetVMs[category] = newVM
            categoryActiveSetVM = newVM
        }
        
        // Create TrainingCoordinator with the cached ActiveSetViewModel
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
            },
            activeSetViewModel: categoryActiveSetVM
        ))
        
        _analyticsViewModel = StateObject(wrappedValue: AnalyticsViewModel())
    }
    
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    private var safeAreaBottomInset: CGFloat { safeAreaInsets.bottom }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            AppStyle.Color.backgroundColor
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.2), value: trainingCoordinator.isTrainingActive)
            
            // Only show content if training is active
            if trainingCoordinator.isTrainingActive {
                VStack(spacing: 0) {
                    Text(exercise.name)
                        .font(AppStyle.Font.navigationHeadline)
                        .foregroundColor(AppStyle.Color.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppStyle.Padding.horizontal)
                        .padding(.top, AppStyle.Padding.titleTop)
                        .padding(.bottom, AppStyle.Padding.titleBottomBeforeActiveCard)
                    
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Active Exercise Card
                            ExerciseCardContainerView(
                                viewModel: ExerciseCardViewModel(exercise: exercise) { updatedExercise in
                                    // Update exercise using ExerciseManagementService
                                    let managementService = ExerciseManagementService()
                                    managementService.updateExercise(updatedExercise, category: category)
                                },
                                onEdit: { exerciseToEdit, _ in
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
                                onCancel: { cancelTraining() },
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
                .padding(.bottom, safeAreaBottomInset + 12) // Standard Positionierung
                
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
                                    cancelTraining()
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
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .onAppear {
            // Start training automatically when view appears
            // Always use .categoryView as start source since we're in dedicated TrainingView
            trainingCoordinator.startTraining(for: exercise)
            
            // Mark that initial load is complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isInitialLoad = false
            }
        }
        .onReceive(trainingCoordinator.$isTrainingActive) { isActive in
            // Handle training completion
            if !isActive && !hasFinishedTraining && !isInitialLoad && !isManuallyNavigatingBack && !overlayState.isCancellingTraining {
                hasFinishedTraining = true
                overlayState.showTrainingMiniMenu = false
                
                // Normal navigation back (cancel is handled separately)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    router.pop()
                }
            } else if !isActive && overlayState.isCancellingTraining {
                hasFinishedTraining = true
                overlayState.showTrainingMiniMenu = false
            }
        }
        .onDisappear {
            isManuallyNavigatingBack = true
            overlayState.showTrainingMiniMenu = false
        }
    }
    
    private func cancelTraining() {
        let targetCategory = trainingCoordinator.activeSetViewModel.originalCategory ?? category
        overlayState.isCancellingTraining = true
        overlayState.showTrainingMiniMenu = false
        router.replaceAll(with: [.home, .muscleCategory(targetCategory)])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            trainingCoordinator.activeSetViewModel.cancelActiveSet()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                overlayState.isCancellingTraining = false
            }
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
                category: .chest
            )
        }
        .environmentObject(UIOverlayState())
        .environmentObject(AppRouter())
    }
}
