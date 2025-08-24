import SwiftUI

struct TrainingView: View {
    let exercise: Exercise
    let category: MuscleCategoryGroup
    let returnDestination: TrainingReturnDestination
    @Binding var navigationPath: NavigationPath
    
    @StateObject private var trainingCoordinator: TrainingCoordinator
    @StateObject private var analyticsViewModel: AnalyticsViewModel
    @EnvironmentObject private var overlayState: UIOverlayState
    
    @State private var hasFinishedTraining = false
    @State private var isInitialLoad = true
    @State private var isManuallyNavigatingBack = false
    @State private var isCancellingTraining = false
    @State private var shouldPreventCustomBackAction = false
    
    init(exercise: Exercise, category: MuscleCategoryGroup, returnDestination: TrainingReturnDestination, navigationPath: Binding<NavigationPath>) {
        self.exercise = exercise
        self.category = category
        self.returnDestination = returnDestination
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
                .animation(.easeInOut(duration: 0.2), value: trainingCoordinator.isTrainingActive)
            
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
                                onCancel: {
                                    print("🔴 TIMER CANCEL in TrainingView!")
                                    print("🔴 Current category: \(category)")
                                    print("🔴 Original category: \(trainingCoordinator.activeSetViewModel.originalCategory?.rawValue ?? "nil")")
                                    print("🔴 Original start source: \(trainingCoordinator.activeSetViewModel.originalStartSource)")
                                    
                                    let targetCategory = trainingCoordinator.activeSetViewModel.originalCategory ?? category
                                    
                                    // WICHTIG: Verhindere customBackAction
                                    overlayState.isCancellingTraining = true
                                    print("🔴 SET isCancellingTraining = true")
                                    
                                    // Sofortige Navigation BEVOR cancelActiveSet
                                    print("🔴 Cancel ALWAYS navigates to CategoryView: \(targetCategory.rawValue)")
                                    var newPath = NavigationPath()
                                    newPath.append(NavigationDestination.home)
                                    newPath.append(NavigationDestination.muscleCategory(targetCategory))
                                    navigationPath = newPath
                                    
                                    // Cancel NACH der Navigation
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        trainingCoordinator.activeSetViewModel.cancelActiveSet()
                                        
                                        // Reset flag after cancel
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                            overlayState.isCancellingTraining = false
                                            print("🔴 RESET isCancellingTraining = false")
                                        }
                                    }
                                },
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
                                    print("🔴 MINI MENU CANCEL CLICKED IN TRAININGVIEW!")
                                    
                                    let targetCategory = trainingCoordinator.activeSetViewModel.originalCategory ?? category
                                    
                                    // WICHTIG: Verhindere customBackAction
                                    overlayState.isCancellingTraining = true
                                    overlayState.showTrainingMiniMenu = false
                                    print("🔴 SET isCancellingTraining = true")
                                    
                                    // Sofortige Navigation BEVOR cancelActiveSet
                                    print("🔴 Mini Menu Cancel navigates to CategoryView: \(targetCategory.rawValue)")
                                    var newPath = NavigationPath()
                                    newPath.append(NavigationDestination.home)
                                    newPath.append(NavigationDestination.muscleCategory(targetCategory))
                                    navigationPath = newPath
                                    
                                    // Cancel NACH der Navigation
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        trainingCoordinator.activeSetViewModel.cancelActiveSet()
                                        
                                        // Reset flag after cancel
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                            overlayState.isCancellingTraining = false
                                            print("🔴 RESET isCancellingTraining = false")
                                        }
                                    }
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
            print("🔵 TRAININGVIEW ONAPPEAR!")
            print("🔵 Exercise: \(exercise.name)")
            print("🔵 Category: \(category)")
            print("🔵 ReturnDestination: \(returnDestination)")
            
            // Start training automatically when view appears
            // Determine start source based on returnDestination
            let startSource: TrainingStartSource = returnDestination == .categoryView ? .categorySelectionView : .categoryView
            print("🔵 Determined startSource: \(startSource)")
            
            trainingCoordinator.startTraining(for: exercise, startSource: startSource)
            print("🔵 Called trainingCoordinator.startTraining!")
            
            // Mark that initial load is complete after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isInitialLoad = false
            }
        }
        .onReceive(trainingCoordinator.$isTrainingActive) { isActive in
            // Only auto-navigate back when training is finished programmatically (completed, cancelled)
            // NOT when user manually navigates back with back button OR when cancelling training
            if !isActive && !hasFinishedTraining && !isInitialLoad && !isManuallyNavigatingBack && !overlayState.isCancellingTraining {
                hasFinishedTraining = true
                // Hide any overlay states
                overlayState.showTrainingMiniMenu = false
                
                print("🔵 onReceive: Normal training completion - navigating back")
                // Normal navigation back (Timer cancel is handled separately)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if !navigationPath.isEmpty {
                        navigationPath.removeLast()
                    }
                }
            } else if !isActive && overlayState.isCancellingTraining {
                print("🔵 onReceive: Training cancelled - skipping auto-navigation (handled by cancel logic)")
                hasFinishedTraining = true
                overlayState.showTrainingMiniMenu = false
            }
        }
        .onDisappear {
            isManuallyNavigatingBack = true
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
                returnDestination: .categorySelectionView,
                navigationPath: .constant(NavigationPath())
            )
        }
        .environmentObject(UIOverlayState())
    }
}
